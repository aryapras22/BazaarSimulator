import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct ExtractedLayoutMapperTests {
    private let food = LegendEntry(name: "Booth A", color: LegendColor(red: 1, green: 0, blue: 0))
    private var legend: Legend { Legend(entries: [food]) }

    private func item(
        _ cls: String, _ box: [Double], id: String? = nil, segment: [Double]? = nil, widthPx: Double? = nil,
        kind: String? = nil, rgb: [Int] = []
    ) -> DetectedItem {
        DetectedItem(cls: cls, box: box, id: id, segment: segment, widthPx: widthPx, kind: kind, legendRgb: rgb)
    }

    @Test("Pixels become metres from a one metre margin, using the given scale")
    func scalesFromTopLeftMargin() throws {
        let plan = DetectedPlan(items: [item("Booth A", [100, 200, 50, 50], id: "A1")])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 25, name: "Plan")

        let booth = try #require(layout.objects.first)
        #expect(booth.placement.sizeM == SIMD2(2, 2))
        #expect(booth.placement.center == SIMD2(2, 2))
        #expect(booth.categoryID == food.id)
        #expect(booth.label == "A1")
    }

    @Test("The scale is chosen so the median booth side is 2.5 m")
    func assumedScale() {
        let plan = DetectedPlan(items: [
            item("Booth A", [0, 0, 40, 40]), item("Booth A", [0, 0, 50, 50]), item("Booth A", [0, 0, 60, 60]),
            item("wall", [0, 0, 900, 10])
        ])

        let scale = ExtractedLayoutMapper.assumedPixelsPerMetre(for: plan)

        #expect(scale == 20)
    }

    @Test("A slanted wall keeps its length, thickness and angle")
    func wallSegment() throws {
        let plan = DetectedPlan(items: [
            item("wall", [0, 0, 30, 40], segment: [0, 0, 30, 40], widthPx: 5)
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let wall = try #require(layout.objects.first)
        #expect(wall.kind == .wall)
        #expect(abs(wall.placement.sizeM.x - 5) < 0.001)
        #expect(wall.placement.sizeM.y == 0.5)
        #expect(abs(wall.placement.rotationRadians - atan2(4, 3)) < 0.001)
    }

    @Test("A swing symbol on a wall gap is the same door as the opening, so only one door is made")
    func swingSymbolOnOpeningMakesOneDoor() {
        let plan = DetectedPlan(items: [
            item("door", [0, 0, 10, 10]),
            item("opening", [0, 0, 30, 5])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.kind) == [.door])
        #expect(layout.objects.first?.doorFlow?.direction == .both)
    }

    @Test("A swing symbol away from any opening becomes a thin detected door along its long side")
    func lonelySwingSymbolBecomesDoor() throws {
        let plan = DetectedPlan(items: [item("door", [100, 0, 20, 40])])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let door = try #require(layout.objects.first)
        #expect(door.kind == .door)
        #expect(door.reviewState == .detected)
        #expect(door.placement.sizeM == SIMD2(4, 0.3))
        #expect(abs(door.placement.rotationRadians - .pi / 2) < 0.001)
    }

    @Test("A table becomes a standard model fitted to its chairs, and chairs without a table become seating")
    func keepsTablesAndChairsAsStandardModels() throws {
        let plan = DetectedPlan(items: [
            item("object", [0, 0, 100, 100], kind: "chair_group"),
            item("object", [40, 40, 20, 20], kind: "table"),
            item("object", [48, 5, 4, 4], kind: "chair"),
            item("object", [48, 91, 4, 4], kind: "chair"),
            item("object", [200, 0, 40, 40], kind: "chair_group"),
            item("object", [200, 0, 4, 4], kind: "chair"),
            item("object", [236, 36, 4, 4], kind: "chair"),
            item("object", [500, 500, 4, 4], kind: "chair")
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let table = try #require(layout.objects.first { $0.kind == .table })
        #expect(table.catalogID == "table-rect-2")
        #expect(table.placement.sizeM == FurnitureModels.table("table-rect-2")?.sizeM)
        let blocks = layout.objects.filter { $0.kind == .seating }
        #expect(blocks.count == 2)
        #expect(blocks.allSatisfy { $0.catalogID == FurnitureModels.seatingBlockID })
        #expect(blocks.map { FurnitureModels.chairs(of: $0).count }.sorted() == [1, 64])
    }

    @Test("A block takes the legend category with its colour")
    func blockCategory() throws {
        let interactive = LegendEntry(name: "Interactive space I", color: LegendColor(red: 1, green: 0.7, blue: 0.1))
        let legend = Legend(entries: [food, interactive])
        let plan = DetectedPlan(items: [item("Interactive space I", [0, 0, 50, 50], rgb: [255, 178, 26])])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.first?.kind == .block)
        #expect(layout.objects.first?.categoryID == interactive.id)
    }

    @Test("Stage and Blocked become hall objects, Entrance is dropped, none become booths")
    func structuralClasses() {
        let legend = Legend(entries: [food, LegendEntry(name: "Stage", color: LegendColor(red: 0, green: 0, blue: 1))])
        let plan = DetectedPlan(items: [
            item("Stage", [0, 0, 100, 50]), item("Blocked", [0, 0, 20, 20]), item("Entrance", [0, 0, 20, 20])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.kind) == [.block, .closedArea])
    }

    @Test("Booths without an ID get U1, U2 labels")
    func unlabeledBooths() {
        let plan = DetectedPlan(items: [
            item("Booth A", [0, 0, 20, 20]),
            item("Booth A", [30, 0, 20, 20], id: "A2"),
            item("Booth A", [60, 0, 20, 20])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.label) == ["U1", "A2", "U2"])
    }

    @Test("A booth named after its ID prefix takes the category with its legend colour")
    func categoryByColour() throws {
        let fashion = LegendEntry(name: "FASHION ZONE", color: LegendColor(red: 0, green: 0, blue: 1))
        let legend = Legend(entries: [food, fashion])
        let plan = DetectedPlan(items: [
            item("Booth F", [0, 0, 20, 20], id: "F1", rgb: [0, 0, 255]),
            item("FACILITIES", [30, 0, 20, 20], rgb: [128, 128, 128])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects[0].kind == .booth)
        #expect(layout.objects[0].categoryID == fashion.id)
        #expect(layout.objects[1].kind == .block)
    }

    @Test("Symbol classes map to walls, doors, blocks and markers according to the symbol mapping")
    func symbolClassMapping() throws {
        let items = [
            DetectedItem(cls: "wall", box: [0, 0, 100, 10], segment: [0, 0, 100, 0], symbolClass: "wall.double"),
            DetectedItem(cls: "opening", box: [20, 0, 30, 10], symbolClass: "door.single_quarter"),
            DetectedItem(cls: "pillar", box: [60, 60, 20, 20], symbolClass: "column.solid_square"),
            DetectedItem(cls: "misc", box: [90, 90, 20, 20], symbolClass: "stairs.boxed"),
            DetectedItem(cls: "misc", box: [120, 120, 20, 20], symbolClass: "restroom.framed"),
            DetectedItem(cls: "arrow", box: [150, 150, 20, 20], symbolClass: "arrow.entry"),
            DetectedItem(cls: "arrow", box: [180, 180, 20, 20], symbolClass: "arrow.exit"),
            DetectedItem(cls: "object", box: [200, 200, 20, 20], symbolClass: "table.blue_filled")
        ]
        let plan = DetectedPlan(items: items)
        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.contains { $0.kind == .wall && $0.placement.sizeM.y == 0.2 })
        #expect(layout.objects.contains { $0.kind == .door })
        #expect(!layout.objects.contains { $0.label == "Pillar" })
        #expect(layout.objects.contains { $0.kind == .block && $0.label == "Stairs" })
        #expect(layout.objects.contains { $0.kind == .block && $0.label == "Restroom" })
        #expect(!layout.objects.contains { $0.label == "table.blue_filled" })

        #expect(layout.markers.count == 2)
        #expect(layout.markers.contains { $0.kind == .spawn })
        #expect(layout.markers.contains { $0.kind == .exit })
    }

    @Test("A door symbol on the swing item adds no second door beside its opening")
    func swingAndOpeningMakeOneDoor() {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "door", box: [0, 0, 30, 30], symbolClass: "door.single_quarter"),
            DetectedItem(cls: "opening", box: [0, 25, 30, 5], symbolClass: "door.single_quarter")
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.filter { $0.kind == .door }.count == 1)
    }

    @Test("An unknown symbol class leaves the extractor's own class in charge")
    func unknownSymbolClassFallsBack() {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "blocked", box: [0, 0, 20, 20], symbolClass: "mystery.shape")
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.kind) == [.closedArea])
    }

    @Test("Pillars are dropped, with or without a symbol class")
    func pillarsAreDropped() {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "pillar", box: [0, 0, 20, 20]),
            DetectedItem(cls: "pillar", box: [40, 0, 20, 20], symbolClass: "column.hollow_circle")
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.isEmpty)
    }

    private func wall(_ left: Double, _ right: Double) -> DetectedItem {
        DetectedItem(cls: "wall", box: [left, 0, right - left, 2], segment: [left, 0, right, 0], widthPx: 2)
    }

    @Test("A wall shorter than a metre is dropped")
    func shortWallIsDropped() {
        let plan = DetectedPlan(items: [wall(0, 50), wall(200, 205)])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.filter { $0.kind == .wall }.count == 1)
    }

    @Test("Two collinear walls with a small gap and no door become one wall")
    func closeWallsJoin() throws {
        let plan = DetectedPlan(items: [wall(0, 100), wall(105, 200)])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let walls = layout.objects.filter { $0.kind == .wall }
        #expect(walls.count == 1)
        #expect(abs(try #require(walls.first).placement.sizeM.x - 20) < 0.001)
    }

    @Test("A door in the gap keeps the two walls apart")
    func doorKeepsWallsApart() {
        let door = DetectedItem(cls: "opening", box: [100, -5, 5, 12])
        let plan = DetectedPlan(items: [wall(0, 100), wall(105, 200), door])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.filter { $0.kind == .wall }.count == 2)
    }

    @Test("A tall wall box is a rotated wall, so its length runs along its own x axis")
    func tallWallBoxIsRotated() throws {
        let plan = DetectedPlan(items: [DetectedItem(cls: "wall", box: [0, 0, 3, 100])])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let wall = try #require(layout.objects.first)
        #expect(abs(wall.placement.sizeM.x - 10) < 0.001)
        #expect(abs(wall.placement.sizeM.y - 0.3) < 0.001)
        #expect(wall.placement.rotationDegrees == 90)
    }

    @Test("A tall thin wall box is long, not a stub, and joins a wall below it")
    func verticalWallsKeepTheirLength() throws {
        let plan = DetectedPlan(items: [
            DetectedItem(cls: "wall", box: [0, 0, 2, 100]),
            DetectedItem(cls: "wall", box: [0, 104, 2, 96])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        let walls = layout.objects.filter { $0.kind == .wall }
        #expect(walls.count == 1)
        #expect(abs(try #require(walls.first).placement.sizeM.x - 20) < 0.001)
    }

    @Test("Walls with a gap of a metre or more stay separate")
    func farWallsStaySeparate() {
        let plan = DetectedPlan(items: [wall(0, 100), wall(110, 210)])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.filter { $0.kind == .wall }.count == 2)
    }
}

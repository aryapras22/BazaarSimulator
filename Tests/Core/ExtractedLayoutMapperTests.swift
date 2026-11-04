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

    @Test("Swing symbols, chairs and chair groups are dropped, openings become doors")
    func dropsSwingSymbolsAndChairs() {
        let plan = DetectedPlan(items: [
            item("door", [0, 0, 10, 10]),
            item("object", [0, 0, 10, 10], kind: "chair"),
            item("object", [0, 0, 10, 10], kind: "chair_group"),
            item("object", [0, 0, 20, 20], kind: "table"),
            item("opening", [0, 0, 30, 5])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.kind).sorted { $0.rawValue < $1.rawValue } == [.door, .table])
        #expect(layout.objects.first { $0.kind == .door }?.doorFlow?.direction == .both)
    }

    @Test("Structural legend classes become hall objects and never booths")
    func structuralClasses() {
        let legend = Legend(entries: [food, LegendEntry(name: "Stage", color: LegendColor(red: 0, green: 0, blue: 1))])
        let plan = DetectedPlan(items: [
            item("Stage", [0, 0, 100, 50]), item("Blocked", [0, 0, 20, 20]), item("Entrance", [0, 0, 20, 20])
        ])

        let layout = ExtractedLayoutMapper.layout(from: plan, legend: legend, pixelsPerMetre: 10, name: "Plan")

        #expect(layout.objects.map(\.kind) == [.stage, .closedArea, .fixture])
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
        #expect(layout.objects[1].kind == .fixture)
    }
}

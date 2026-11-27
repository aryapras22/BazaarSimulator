import AppKit
import SpriteKit
import SwiftUI
import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct SimulationPlayerViewModelTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", mix: ["a": 50, "b": 50])],
        defaultTotalVisitors: 150
    )

    private func makeModel(layoutCount: Int = 2, layout: LayoutID = .one) -> SimulationPlayerViewModel {
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = 400
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let layouts = (0..<layoutCount).map { _ in TestLayouts.hall() }
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(parameters, for: project.id)
        return SimulationPlayerViewModel(
            projectID: project.id, layoutID: layout, session: session,
            analysisService: AnalysisService(), catalog: catalog
        )
    }

    @Test("It starts out loading")
    func startsLoading() {
        #expect(makeModel().phase == .loading)
    }

    @Test("With no layout there is nothing to play")
    func needsLayouts() async {
        let model = makeModel(layoutCount: 0)
        await model.load()
        #expect(model.phase == .needsLayouts)
    }

    @Test("A project with one layout can still be simulated")
    func oneLayoutPlays() async {
        let model = makeModel(layoutCount: 1)
        await model.load()
        #expect(model.phase == .ready)
        #expect(model.replay != nil)
    }

    @Test("With two layouts it is ready, and shows the full event duration")
    func ready() async {
        let model = makeModel()
        await model.load()
        #expect(model.phase == .ready)
        #expect(model.windowText == "10:00 - 13:00")
        #expect(model.outcome?.name == "Layout 1")
        #expect(model.replay != nil)
        #expect(model.planAspect > 0)
    }

    @Test("The playback clock advances 30 simulated seconds per real second across the full event")
    func clockText() async {
        let model = makeModel()
        await model.load()
        #expect(SimulationPlayerViewModel.simulatedSecondsPerPlaybackSecond == 30)
        #expect(model.playbackDuration == 360)
        #expect(model.windowSeconds(at: 1) == 30)
        #expect(model.clockText(at: 0) == "10:00")
        #expect(model.clockText(at: 180) == "11:30")
        #expect(model.clockText(at: 360) == "13:00")
        #expect(model.progress(at: 180) == 0.5)
        #expect(model.progress(at: 600) == 1)
        #expect(model.windowSeconds(at: 360) == 10_800)
    }

    @Test("Visitors are drawn on the plan, and are counted by the people in them")
    func visitors() async throws {
        let model = makeModel()
        await model.load()
        let replay = try #require(model.replay)
        var busiest = 0.0
        var most = 0
        for step in 0...20 {
            let time = Double(step) * (model.playbackDuration / 20)
            let count = model.visitorsInside(at: time)
            if count > most { most = count; busiest = time }
        }
        #expect(most > 0)
        let drawn = model.visitors(at: busiest)
        #expect(!drawn.isEmpty)
        #expect(drawn.allSatisfy { (0...1).contains($0.point.x) && (0...1).contains($0.point.y) })
        #expect(drawn.allSatisfy { $0.typeIndex < TestLayouts.visitorTypes.count })
        let frame = try #require(replay.frame(at: model.windowSeconds(at: busiest)))
        #expect(model.visitorsInside(at: busiest) == frame.visitors.reduce(0) { $0 + $1.people })
    }

    @Test("Between two frames a visitor is between the two places")
    func visitorsMoveSmoothly() async throws {
        let model = makeModel()
        await model.load()
        let replay = try #require(model.replay)
        let stepPlayback = model.playbackDuration / Double(max(replay.frames.count - 1, 1))
        let index = try #require((0..<(replay.frames.count - 1)).first { frameIndex in
            let next = replay.frames[frameIndex + 1].visitors
            return replay.frames[frameIndex].visitors.contains { visitor in
                next.contains { other in other.id == visitor.id && other.position != visitor.position }
            }
        })
        let start = Double(index) * stepPlayback
        let before = model.visitors(at: start)
        let halfway = model.visitors(at: start + stepPlayback * 0.5)
        let after = model.visitors(at: start + stepPlayback)
        let moved = zip(before, halfway).contains { $0.point != $1.point }
        #expect(moved)
        #expect(before.count == replay.frames[index].visitors.count)
        #expect(after.count == replay.frames[index + 1].visitors.count)
    }

    @Test("Footfall grows through the window")
    func footfall() async {
        let model = makeModel()
        await model.load()
        let early = model.footfallSummary(at: 40)
        let late = model.footfallSummary(at: model.playbackDuration)
        #expect(late.total >= early.total)
        #expect(late.busiest >= early.busiest)
        #expect(late.total > 0)
    }

    @Test("Crowd density comes out per heat cell and never negative")
    func density() async {
        let model = makeModel()
        await model.load()
        let heat = model.heatDensity(at: 60)
        #expect(heat.count == SimulationPlayerViewModel.heatColumns * model.heatRows)
        #expect(heat.allSatisfy { $0 >= 0 && $0.isFinite })
        #expect(model.heatCoverage.count == heat.count)
        #expect(!model.walkablePath.isEmpty)
    }

    @Test("A spot's grade matches a recount of the people standing in its square of floor")
    func gradesMatchVisitors() async throws {
        let model = makeModel()
        await model.load()
        let replay = try #require(model.replay)
        let outcome = try #require(model.outcome)
        let analysis = try #require(model.result?.analyses[.one])
        let mask = replay.walkable
        var total = 0, matching = 0
        for (spot, measured) in zip(outcome.spots, analysis.spots) {
            let half = 1.5
            let inBlock = { (posX: Double, posY: Double) in
                abs(posX - measured.position.x) <= half && abs(posY - measured.position.y) <= half
            }
            var cells = 0
            for row in 0..<mask.rows {
                for column in 0..<mask.columns where mask.cells[row * mask.columns + column] {
                    let cellX = mask.origin.x + (Double(column) + 0.5) * mask.cellSizeM
                    let cellY = mask.origin.y + (Double(row) + 0.5) * mask.cellSizeM
                    if inBlock(cellX, cellY) { cells += 1 }
                }
            }
            let area = Double(cells) * mask.cellSizeM * mask.cellSizeM
            guard area > 0 else { continue }
            for frameIndex in stride(from: 0, to: replay.frames.count, by: 10) {
                let people = replay.frames[frameIndex].visitors
                    .filter { inBlock(Double($0.position.x), Double($0.position.y)) }
                    .reduce(0) { $0 + $1.people }
                let playbackTime = Double(frameIndex * replay.frameIntervalSeconds) / replay.durationSeconds
                    * model.playbackDuration
                let shown = model.spotDensity(for: spot, at: playbackTime)
                total += 1
                if SeverityGrade.grade(forDensity: Double(people) / area) == SeverityGrade.grade(forDensity: shown) {
                    matching += 1
                }
            }
        }
        #expect(total > 0)
        #expect(Double(matching) / Double(total) >= 0.9)
    }

    @Test("The window is titled with the bazaar and the layout")
    func windowTitle() {
        #expect(makeModel().windowTitle == "P · Layout 1")
        #expect(makeModel(layout: .two).windowTitle == "P · Layout 2")
    }

    @Test("Layout 2 plays the second layout")
    func secondLayout() async {
        let model = makeModel(layout: .two)
        await model.load()
        #expect(model.outcome?.name == "Layout 2")
    }

    @Test("2D and 3D congestion hotspots stay hidden until Grade E or F, then stay visible")
    func congestionHotspotsRequireGradeEOrF() async throws {
        let model = makeModel()
        await model.load()
        model.mode = .congestion
        let spots = try #require(model.outcome?.spots)
        #expect(model.spriteOverlayCells(at: 0).isEmpty)
        #expect(model.sceneFrame(at: 0).spots.isEmpty)
        for spot in spots {
            #expect(!model.isCongestedSpot(spot, at: 0))
        }
        var previouslyShown: Set<Int> = []
        for step in 0...10 {
            let time = Double(step) * (model.playbackDuration / 10)
            let expectedIDs = Set(spots.filter { model.isCongestedSpot($0, at: time) }.map(\.number))
            let shown2D = Set(model.spriteOverlayCells(at: time).map(\.id))
            let shown3D = Set(model.sceneFrame(at: time).spots.map(\.number))
            #expect(shown2D == expectedIDs)
            #expect(shown3D == expectedIDs)
            #expect(previouslyShown.isSubset(of: expectedIDs))
            previouslyShown = expectedIDs
        }
    }
}

@Suite
struct PlaybackClockTests {
    @Test("It stays put until played, and counts up while playing")
    func playing() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        #expect(clock.time(at: start.addingTimeInterval(10)) == 0)
        clock.play(from: start)
        #expect(clock.time(at: start.addingTimeInterval(10)) == 10)
    }

    @Test("Pausing holds the time")
    func pausing() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        clock.play(from: start)
        clock.pause(at: start.addingTimeInterval(30))
        #expect(clock.time(at: start.addingTimeInterval(90)) == 30)
    }

    @Test("Speed scales how fast time passes, without a jump")
    func speed() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        clock.play(from: start)
        clock.setSpeed(2, at: start.addingTimeInterval(10))
        #expect(clock.time(at: start.addingTimeInterval(10)) == 10)
        #expect(clock.time(at: start.addingTimeInterval(20)) == 30)
    }

    @Test("Playback speed options are 1x, 2x, and 4x only")
    func speedOptions() {
        #expect(PlaybackClock.speeds == [1, 2, 4])
        #expect(PlaybackClock.speeds.map(PlaybackBar.speedLabel) == ["1x", "2x", "4x"])
    }

    @Test("Toggle starts, pauses, resumes, and restarts after finishing")
    func togglePlayback() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        clock.toggle(at: start)
        #expect(clock.isRunning)

        clock.toggle(at: start.addingTimeInterval(20))
        #expect(!clock.isRunning)
        #expect(clock.time(at: start.addingTimeInterval(40)) == 20)

        clock.toggle(at: start.addingTimeInterval(40))
        #expect(clock.isRunning)
        #expect(clock.time(at: start.addingTimeInterval(50)) == 30)

        clock.toggle(at: start.addingTimeInterval(300))
        #expect(clock.isRunning)
        #expect(clock.time(at: start.addingTimeInterval(305)) == 5)
    }

    @Test("It stops at the end, and playing again starts over")
    func end() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        clock.play(from: start)
        #expect(clock.time(at: start.addingTimeInterval(500)) == 120)
        clock.pause(at: start.addingTimeInterval(500))
        clock.play(from: start.addingTimeInterval(600))
        #expect(clock.time(at: start.addingTimeInterval(605)) == 5)
    }

    @Test("Seeking back after the end stays paused")
    func seekAfterEnd() {
        var clock = PlaybackClock(duration: 120)
        let start = Date()
        clock.play(from: start)
        clock.seek(to: 30, at: start.addingTimeInterval(500))
        #expect(!clock.isRunning)
        #expect(clock.time(at: start.addingTimeInterval(510)) == 30)
    }
}


@MainActor
@Suite
struct SimulationPlayerSceneTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", mix: ["a": 50, "b": 50])],
        defaultTotalVisitors: 150
    )

    private func loadedModel() async -> SimulationPlayerViewModel {
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = 400
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: [TestLayouts.hall(), TestLayouts.hall()]), for: project.id)
        session.setEventParameters(parameters, for: project.id)
        let model = SimulationPlayerViewModel(
            projectID: project.id, layoutID: .one, session: session,
            analysisService: AnalysisService(), catalog: catalog
        )
        await model.load()
        return model
    }

    @Test("It starts in 2D")
    func startsFlat() async {
        #expect(await loadedModel().viewStyle == .twoD)
        #expect(SimulationViewStyle.allCases.map(\.title) == ["2D", "3D"])
    }

    @Test("There is a 3D venue once the simulation has loaded, and it is built once")
    func venueIsBuiltOnce() async throws {
        let model = await loadedModel()
        let first = try #require(model.venue())
        #expect(first.id == model.venue()?.id)
        #expect(first.blocks.count >= TestLayouts.hall().objects.count)
        #expect(first.plan == model.plan)
    }

    @Test("Visitors are placed in layout meters, inside the plan")
    func visitorsInMeters() async {
        let model = await loadedModel()
        let plan = model.plan
        let frame = model.sceneFrame(at: 60)
        #expect(frame.visitors.count == model.visitors(at: 60).count)
        #expect(!frame.visitors.isEmpty)
        for visitor in frame.visitors {
            #expect(visitor.x >= plan.origin.x && visitor.x <= plan.origin.x + plan.size.x)
            #expect(visitor.z >= plan.origin.y && visitor.z <= plan.origin.y + plan.size.y)
        }
        #expect(Set(frame.visitors.map(\.id)).count == frame.visitors.count)
    }

    @Test("Congestion marks hotspots once they reach Grade E or F, with no floor overlay")
    func congestion() async {
        let model = await loadedModel()
        model.mode = .congestion
        let startFrame = model.sceneFrame(at: 0)
        #expect(startFrame.spots.isEmpty)
        #expect(startFrame.overlay == nil)

        let endFrame = model.sceneFrame(at: model.playbackDuration)
        let expectedCount = (model.outcome?.spots ?? []).filter {
            model.isCongestedSpot($0, at: model.playbackDuration)
        }.count
        #expect(endFrame.spots.count == expectedCount)
        #expect(endFrame.overlay == nil)
        #expect(endFrame.spots.allSatisfy { (0...1).contains($0.level) })
    }

    @Test("Crowd density and busiest path paint the floor, with no spot markers")
    func overlays() async throws {
        let model = await loadedModel()
        let mask = try #require(model.replay?.walkable)
        for mode in [SimulationMode.density, .footfall] {
            model.mode = mode
            let frame = model.sceneFrame(at: 120)
            let overlay = try #require(frame.overlay, "\(mode)")
            #expect(overlay.width == mask.columns && overlay.height == mask.rows)
            #expect(frame.spots.isEmpty)
        }
    }

    @Test("Visitors appear in every mode")
    func visitorsEverywhere() async {
        let model = await loadedModel()
        for mode in SimulationMode.allCases {
            model.mode = mode
            #expect(!model.sceneFrame(at: 60).visitors.isEmpty, "\(mode)")
        }
    }

    @Test("Normalized walking routes separate low-traffic aisles from busy arteries even with an outlier spike")
    func normalizedFootfallResistsOutliers() {
        var counts: [UInt16] = [0, 5, 10, 20, 40, 80, 90, 95, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 900]
        let normalized = SimulationPlayerViewModel.normalizedFootfall(for: counts)
        #expect(normalized[0] == 0)
        #expect(normalized[1] > 0 && normalized[1] < 0.2)
        #expect(normalized[5] > 0.7)
        #expect(normalized[19] == 1.0)
        #expect(normalized[1] < normalized[3] && normalized[3] < normalized[5])

        counts = [0, 0, 0]
        #expect(SimulationPlayerViewModel.normalizedFootfall(for: counts) == [0, 0, 0])
        #expect(CrowdMeasuringRun.tileCells == 1)

        // Smoothing bridges adjacent tiles into continuous paths rather than isolated grid points.
        let line: [UInt16] = [
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            50, 50, 50, 50, 50,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0
        ]
        let smoothed = SimulationPlayerViewModel.smoothedFootfall(for: line, columns: 5, rows: 5)
        #expect(smoothed[12] > 0.8)
        #expect(smoothed[7] > 0 && smoothed[7] < smoothed[12])
        #expect(smoothed[0] == 0)
    }

    @Test("Simulation modes expose Stuck Spots, Crowd Level, and Walking Routes tabs")
    func modeTitles() {
        #expect(SimulationMode.allCases.map(\.title) == ["Stuck Spots", "Crowd Level", "Walking Routes"])
    }

    @Test("Tenant categories use fixed picker order, boothType colors, and entertainment resolution")
    func tenantColorsDifferentiateCategories() {
        let fnbEntry = LegendEntry(name: "FNB", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        let fashionEntry = LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)
        let hobbiesEntry = LegendEntry(name: "Hobbies", color: LegendColor(red: 1, green: 1, blue: 0), type: .goods)
        let legend = Legend(entries: [fnbEntry, fashionEntry, hobbiesEntry])
        let place = Placement(center: .zero, sizeM: SIMD2(2, 2))
        let wallOnly = Layout(
            name: "Empty", sizeM: SIMD2(20, 20), objects: [LayoutObject(kind: .wall, label: "W1", placement: place)]
        )
        #expect(TenantColors.legendItems(for: nil, legend: legend).isEmpty)
        #expect(TenantColors.legendItems(for: wallOnly, legend: legend).isEmpty)

        func attraction(_ label: String, catalogID: String? = nil) -> LayoutObject {
            LayoutObject(kind: .entertainment, label: label, placement: place, catalogID: catalogID)
        }
        let unassigned = LayoutObject(kind: .booth, label: "Food 1", placement: place, categoryID: fnbEntry.id)
        let foods = LayoutObject(
            kind: .booth, label: "B1", placement: place, categoryID: fashionEntry.id, boothType: .fnb
        )
        let goods = LayoutObject(
            kind: .booth, label: "F1", placement: place, categoryID: hobbiesEntry.id, boothType: .goods
        )
        let attractions = [
            attraction("Closed", catalogID: EntertainmentType.disabled.catalogID),
            attraction("Area Lomba"),
            attraction("Info Desk"),
            attraction("Stage", catalogID: EntertainmentType.photobooth.catalogID),
            attraction("Main Stage")
        ]
        let fullLayout = Layout(
            name: "Full", sizeM: SIMD2(30, 20), objects: attractions + [goods, foods, unassigned, foods]
        )

        let items = TenantColors.legendItems(for: fullLayout, legend: legend)
        let expectedNames = ["Unassigned", "Foods", "Goods"] + EntertainmentType.allCases.map(\.displayName)
        #expect(items.map(\.name) == expectedNames)
        #expect(!TenantColors.isFood(unassigned, legend: legend))
        #expect(TenantColors.isFood(foods, legend: legend))
        #expect(!TenantColors.isFood(goods, legend: legend))

        let rgbaByName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.rgba) })
        #expect(TenantColors.boothRGBA(for: unassigned, legend: legend) == rgbaByName["Unassigned"])
        #expect(TenantColors.boothRGBA(for: foods, legend: legend) == TenantColors.foodRGBA)
        #expect(rgbaByName["Foods"] == TenantColors.foodRGBA)
        #expect(TenantColors.boothRGBA(for: goods, legend: legend) == TenantColors.goodsPalette[0])
        #expect(rgbaByName["Goods"] == TenantColors.goodsPalette[0])
        #expect(Set(items.prefix(3).map(\.rgba)).count == 3)
        #expect(Set(items.dropFirst(3).map(\.rgba)).count == EntertainmentType.allCases.count)
    }

    @Test("Legend filters to present categories and ignores imported entries in ViewModel")
    func tenantLegendFiltersPresentCategories() async {
        let imported = LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)
        let legend = Legend(entries: [imported])
        let place = Placement(center: SIMD2(6, 6), sizeM: SIMD2(2, 2))

        let filteredLayout = Layout(
            name: "Subset", sizeM: SIMD2(20, 20),
            objects: [
                LayoutObject(kind: .entertainment, label: "PHOTO BOX", placement: place),
                LayoutObject(kind: .booth, label: "B1", placement: place, categoryID: imported.id, boothType: .goods),
                LayoutObject(kind: .door, label: "D1", placement: place)
            ]
        )
        #expect(TenantColors.legendItems(for: filteredLayout, legend: legend).map(\.name) == ["Goods", "Photobooth"])

        let session = ProjectSession()
        let project = session.createProject(named: "Legend")
        var hall = TestLayouts.hall()
        hall.objects[0].boothType = .fnb
        hall.objects[1].boothType = .goods
        session.setDraft(ProjectDraft(name: "Legend", legend: legend, layouts: [hall]), for: project.id)
        session.setEventParameters(TestLayouts.parameters, for: project.id)
        let model = SimulationPlayerViewModel(
            projectID: project.id, layoutID: .one, session: session,
            analysisService: AnalysisService(), catalog: catalog
        )
        #expect(model.tenantTypes.isEmpty)
        await model.load()
        #expect(model.tenantTypes.map(\.name) == ["Unassigned", "Foods", "Goods"])
    }

    @Test("2D booth and entertainment fills match their legend dot colors")
    func tenantLegendMatches2DFills() throws {
        let imported = LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)
        let legend = Legend(entries: [imported])
        let place = Placement(center: SIMD2(6, 6), sizeM: SIMD2(2, 2))

        let allObjects: [(category: String, object: LayoutObject)] = [
            ("Unassigned", LayoutObject(kind: .booth, label: "F1", placement: place, categoryID: imported.id)),
            ("Foods", LayoutObject(kind: .booth, label: "B1", placement: place, boothType: .fnb)),
            ("Goods", LayoutObject(kind: .booth, label: "F2", placement: place, boothType: .goods)),
            ("Stage", LayoutObject(kind: .entertainment, label: "Main Stage", placement: place)),
            ("Photobooth", LayoutObject(
                kind: .entertainment, label: "Stage", placement: place,
                catalogID: EntertainmentType.photobooth.catalogID
            )),
            ("Information Desk", LayoutObject(kind: .entertainment, label: "Info", placement: place)),
            ("Others", LayoutObject(kind: .entertainment, label: "Display", placement: place)),
            ("Disabled", LayoutObject(
                kind: .entertainment, label: "Off", placement: place,
                catalogID: EntertainmentType.disabled.catalogID
            ))
        ]
        let layout = Layout(name: "2D Parity", sizeM: SIMD2(24, 12), objects: allObjects.map(\.object))
        let legendColors = Dictionary(
            uniqueKeysWithValues: TenantColors.legendItems(for: layout, legend: legend).map { ($0.name, $0.nsColor) }
        )

        let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let scene = Venue2DScene(size: CGSize(width: 400, height: 300))
        view.presentScene(scene)
        scene.updateScene(layout: layout, legend: legend, visitors: [], densityCells: [], showHeatmap: false)

        let objectLayer = try #require(scene.children.first { $0.zPosition == 2 })
        let nodes = objectLayer.children.compactMap { $0 as? SKShapeNode }
        #expect(nodes.count == allObjects.count)
        for (entry, node) in zip(allObjects, nodes) {
            let expected = try #require(legendColors[entry.category], "Missing legend item for \(entry.category)")
            let actualRGB = try #require(node.fillColor.usingColorSpace(.sRGB))
            let expectedRGB = try #require(expected.usingColorSpace(.sRGB))
            #expect(abs(actualRGB.redComponent - expectedRGB.redComponent) < 0.002, "\(entry.category)")
            #expect(abs(actualRGB.greenComponent - expectedRGB.greenComponent) < 0.002, "\(entry.category)")
            #expect(abs(actualRGB.blueComponent - expectedRGB.blueComponent) < 0.002, "\(entry.category)")
            #expect(abs(actualRGB.alphaComponent - expectedRGB.alphaComponent) < 0.002, "\(entry.category)")
        }
    }
}

private struct ObjectColorCase {
    let name: String
    let object: LayoutObject
    let expected: SIMD4<Float>
}

extension SimulationPlayerSceneTests {
    private func allKindColorCases() -> [ObjectColorCase] {
        let place = Placement(center: SIMD2(6, 6), sizeM: SIMD2(2, 2))
        func item(
            _ name: String, _ kind: LayoutObjectKind, label: String = "X",
            boothType: BoothType? = nil, catalogID: String? = nil,
            direction: DoorDirection? = nil, expected: SIMD4<Float>
        ) -> ObjectColorCase {
            let object = LayoutObject(
                kind: kind, label: label, placement: place, boothType: boothType,
                doorFlow: direction.map { DoorFlow(direction: $0) }, catalogID: catalogID
            )
            return ObjectColorCase(name: name, object: object, expected: expected)
        }
        return [
            item("booth-nil", .booth, expected: TenantColors.unassignedRGBA),
            item("booth-fnb", .booth, boothType: .fnb, expected: TenantColors.foodRGBA),
            item("booth-goods", .booth, boothType: .goods, expected: TenantColors.goodsPalette[0]),
            item("stage", .entertainment, label: "Main Stage", expected: TenantColors.entertainmentRGBA(for: .stage)),
            item("photobooth", .entertainment, catalogID: EntertainmentType.photobooth.catalogID,
                 expected: TenantColors.entertainmentRGBA(for: .photobooth)),
            item("info", .entertainment, label: "Info Desk",
                 expected: TenantColors.entertainmentRGBA(for: .informationDesk)),
            item("other-ent", .entertainment, label: "Display", expected: TenantColors.entertainmentRGBA(for: .other)),
            item("disabled-ent", .entertainment, catalogID: EntertainmentType.disabled.catalogID,
                 expected: TenantColors.entertainmentRGBA(for: .disabled)),
            item("table", .table, expected: VenueGeometry.yellowColor),
            item("seating", .seating, expected: VenueGeometry.paleBlueColor),
            item("wall", .wall, expected: VenueGeometry.whiteColor),
            item("block", .block, expected: VenueGeometry.blockColor),
            item("column", .block, catalogID: ObjectCatalog.columnID, expected: VenueGeometry.cobaltColor),
            item("closedArea", .closedArea, expected: VenueGeometry.paleBlueColor),
            item("door-entrance", .door, direction: .entrance, expected: SIMD4(0.18, 0.62, 0.42, 1)),
            item("door-exit", .door, direction: .exit, expected: SIMD4(0.85, 0.20, 0.22, 1)),
            item("door-both", .door, direction: .both, expected: SIMD4(0.20, 0.38, 0.75, 1)),
            item("door-disabled", .door, direction: .disabled, expected: SIMD4(0.62, 0.64, 0.68, 1)),
            item("door-default", .door, expected: SIMD4(0.20, 0.38, 0.75, 1))
        ]
    }

    private func assertColor(_ actual: NSColor, matches expected: SIMD4<Float>, _ label: String) throws {
        let srgb = try #require(actual.usingColorSpace(.sRGB), "\(label)")
        #expect(abs(srgb.redComponent - CGFloat(expected.x)) < 0.002, "\(label) red")
        #expect(abs(srgb.greenComponent - CGFloat(expected.y)) < 0.002, "\(label) green")
        #expect(abs(srgb.blueComponent - CGFloat(expected.z)) < 0.002, "\(label) blue")
        #expect(abs(srgb.alphaComponent - CGFloat(expected.w)) < 0.002, "\(label) alpha")
    }

    @Test("TenantColors.objectRGBA maps every object kind and matches Venue2DScene fills")
    func objectRGBACoversAllKindsAndMatches2DScene() throws {
        let cases = allKindColorCases()
        for entry in cases {
            #expect(TenantColors.objectRGBA(for: entry.object) == entry.expected, "\(entry.name)")
        }

        let hall = [SIMD2<Double>(0, 0), SIMD2(24, 0), SIMD2(24, 12), SIMD2(0, 12)]
        let lobby = [SIMD2<Double>(0, 12), SIMD2(24, 12), SIMD2(24, 16), SIMD2(0, 16)]
        let layout = Layout(
            name: "All Kinds", sizeM: SIMD2(24, 16), hall: hall, lobby: lobby, objects: cases.map(\.object)
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let scene = Venue2DScene(size: CGSize(width: 400, height: 300))
        view.presentScene(scene)
        scene.updateScene(layout: layout, visitors: [], densityCells: [], showHeatmap: false)

        let floorLayer = try #require(scene.children.first { $0.zPosition == 0 && !($0 is SKCameraNode) })
        let floorNodes = floorLayer.children.compactMap { $0 as? SKShapeNode }
        try #require(floorNodes.count == 2)
        try assertColor(floorNodes[0].fillColor, matches: TenantColors.hallFloorRGBA, "hall")
        try assertColor(floorNodes[1].fillColor, matches: TenantColors.lobbyFloorRGBA, "lobby")
        try assertColor(floorNodes[0].strokeColor, matches: TenantColors.outlineRGBA, "hall-stroke")

        let objectLayer = try #require(scene.children.first { $0.zPosition == 2 })
        let nodes = objectLayer.children.compactMap { $0 as? SKShapeNode }
        #expect(nodes.count == cases.count)
        for (entry, node) in zip(cases, nodes) {
            try assertColor(node.fillColor, matches: entry.expected, entry.name)
            try assertColor(node.strokeColor, matches: TenantColors.outlineRGBA, "\(entry.name)-stroke")
        }
    }
}

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

    @Test("The playback clock shows the time of day across the full event")
    func clockText() async {
        let model = makeModel()
        await model.load()
        #expect(SimulationPlayerViewModel.playbackSeconds == 480)
        #expect(model.clockText(at: 0) == "10:00")
        #expect(model.clockText(at: 240) == "11:30")
        #expect(model.clockText(at: 480) == "13:00")
        #expect(model.progress(at: 240) == 0.5)
        #expect(model.progress(at: 600) == 1)
        #expect(model.windowSeconds(at: 480) == 10_800)
    }

    @Test("Visitors are drawn on the plan, and are counted by the people in them")
    func visitors() async throws {
        let model = makeModel()
        await model.load()
        let replay = try #require(model.replay)
        var busiest = 0.0
        var most = 0
        for step in 0...20 {
            let time = Double(step) * (SimulationPlayerViewModel.playbackSeconds / 20)
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
        let stepPlayback = SimulationPlayerViewModel.playbackSeconds / Double(max(replay.frames.count - 1, 1))
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
        let late = model.footfallSummary(at: SimulationPlayerViewModel.playbackSeconds)
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
            let inBlock = { (x: Double, y: Double) in abs(x - measured.position.x) <= half && abs(y - measured.position.y) <= half }
            var cells = 0
            for row in 0..<mask.rows {
                for column in 0..<mask.columns where mask.cells[row * mask.columns + column] {
                    let x = mask.origin.x + (Double(column) + 0.5) * mask.cellSizeM
                    let y = mask.origin.y + (Double(row) + 0.5) * mask.cellSizeM
                    if inBlock(x, y) { cells += 1 }
                }
            }
            let area = Double(cells) * mask.cellSizeM * mask.cellSizeM
            guard area > 0 else { continue }
            for frameIndex in stride(from: 0, to: replay.frames.count, by: 10) {
                let people = replay.frames[frameIndex].visitors
                    .filter { inBlock(Double($0.position.x), Double($0.position.y)) }
                    .reduce(0) { $0 + $1.people }
                let playbackTime = Double(frameIndex * replay.frameIntervalSeconds) / replay.durationSeconds
                    * SimulationPlayerViewModel.playbackSeconds
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

    @Test("Congestion marks the watched spots, with no floor overlay")
    func congestion() async {
        let model = await loadedModel()
        model.mode = .congestion
        let frame = model.sceneFrame(at: 60)
        #expect(frame.spots.count == model.outcome?.spots.count)
        #expect(frame.overlay == nil)
        #expect(frame.spots.allSatisfy { (0...1).contains($0.level) })
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

    @Test("Simulation modes expose Congestion Spots, Crowd Level, and Walking Routes tabs")
    func modeTitles() {
        #expect(SimulationMode.allCases.map(\.title) == ["Congestion Spots", "Crowd Level", "Walking Routes"])
    }

    @Test("Tenant categories receive distinct colors for the legend and booths")
    func tenantColorsDifferentiateCategories() {
        let fnb = LegendEntry(name: "FNB", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        let fashion = LegendEntry(name: "Fashion", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)
        let hobbies = LegendEntry(name: "Lifestyle & Hobbies", color: LegendColor(red: 1, green: 1, blue: 0), type: .goods)
        let legend = Legend(entries: [fnb, fashion, hobbies])

        let items = TenantColors.legendItems(for: nil, legend: legend)
        #expect(items.map(\.name) == ["FNB", "Fashion", "Lifestyle & Hobbies"])
        #expect(Set(items.map(\.rgba)).count == 3)

        let fnbBooth = LayoutObject(
            kind: .booth, label: "F1", placement: Placement(center: .zero, sizeM: SIMD2(2, 2)), categoryID: fnb.id
        )
        let fashionBooth = LayoutObject(
            kind: .booth, label: "B1", placement: Placement(center: .zero, sizeM: SIMD2(2, 2)), categoryID: fashion.id
        )
        #expect(TenantColors.boothRGBA(for: fnbBooth, legend: legend) == items[0].rgba)
        #expect(TenantColors.boothRGBA(for: fashionBooth, legend: legend) == items[1].rgba)
        #expect(items[0].rgba != items[1].rgba)
    }
}

import SwiftUI
import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct SimulationPlayerViewModelTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
    )

    private func makeModel(layoutCount: Int = 2, layout: LayoutID = .one) -> SimulationPlayerViewModel {
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = 400
        parameters.peakPeriods = [TimeRange(startMinute: 11 * 60, endMinute: 12 * 60)]
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

    @Test("With fewer than two layouts there is nothing to play")
    func needsLayouts() async {
        let model = makeModel(layoutCount: 1)
        await model.load()
        #expect(model.phase == .needsLayouts)
    }

    @Test("With two layouts it is ready, and shows the busiest window")
    func ready() async {
        let model = makeModel()
        await model.load()
        #expect(model.phase == .ready)
        #expect(model.windowText == "11:00 - 11:10")
        #expect(model.outcome?.name == "Layout 1")
        #expect(model.replay != nil)
        #expect(model.planAspect > 0)
    }

    @Test("The playback clock shows the time of day inside the window")
    func clockText() async {
        let model = makeModel()
        await model.load()
        #expect(model.clockText(at: 0) == "11:00")
        #expect(model.clockText(at: 60) == "11:05")
        #expect(model.clockText(at: 120) == "11:10")
        #expect(model.progress(at: 60) == 0.5)
        #expect(model.progress(at: 500) == 1)
        #expect(model.windowSeconds(at: 120) == 600)
    }

    @Test("Visitors are drawn on the plan, and are counted by the people in them")
    func visitors() async throws {
        let model = makeModel()
        await model.load()
        let replay = try #require(model.replay)
        var busiest = 0.0
        var most = 0
        for step in 0...20 {
            let time = Double(step) * 6
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
        // Frame i sits at playback i * 1.2 seconds.
        let index = try #require((0..<100).first { frameIndex in
            let next = replay.frames[frameIndex + 1].visitors
            return replay.frames[frameIndex].visitors.contains { visitor in
                next.contains { other in other.id == visitor.id && other.position != visitor.position }
            }
        })
        let start = Double(index) * 1.2
        let before = model.visitors(at: start)
        let halfway = model.visitors(at: start + 0.6)
        let after = model.visitors(at: start + 1.2)
        let moved = zip(before, halfway).contains { $0.point != $1.point }
        #expect(moved)
        #expect(before.count == replay.frames[index].visitors.count)
        #expect(after.count == replay.frames[index + 1].visitors.count)
    }

    @Test("Footfall grows through the window")
    func footfall() async {
        let model = makeModel()
        await model.load()
        let early = model.footfallSummary(at: 10)
        let late = model.footfallSummary(at: 120)
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
            for frameIndex in stride(from: 0, to: replay.frames.count, by: 5) {
                let people = replay.frames[frameIndex].visitors
                    .filter { inBlock(Double($0.position.x), Double($0.position.y)) }
                    .reduce(0) { $0 + $1.people }
                let shown = spot.density(at: Double(frameIndex * replay.frameIntervalSeconds) / replay.durationSeconds)
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

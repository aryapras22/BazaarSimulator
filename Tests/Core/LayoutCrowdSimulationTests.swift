import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct LayoutCrowdSimulationTests {
    private func run(
        layout: Layout = TestLayouts.hall(),
        parameters: EventParameters = TestLayouts.parameters,
        types: [VisitorType] = TestLayouts.visitorTypes,
        seed: UInt64 = 42,
        focus: TimeRange? = nil
    ) -> LayoutAnalysis {
        LayoutCrowdSimulation(input: SimulationInput(
            layout: layout, parameters: parameters, visitorTypes: types, seed: seed, focus: focus
        )).runToEnd()
    }

    private func peakDensity(_ analysis: LayoutAnalysis) -> Float {
        analysis.spots.flatMap(\.densitySamples).max() ?? 0
    }

    @Test("Samples cover the event: one every 10 seconds, and one flow value per minute")
    func sampleShape() {
        let analysis = run()
        #expect(analysis.eventStartMinute == 600)
        #expect(analysis.sampleIntervalSeconds == 10)
        #expect(analysis.flowPerMinute.count == 181)
        #expect(!analysis.spots.isEmpty)
        #expect(analysis.spots.allSatisfy { $0.densitySamples.count == 3 * 60 * 6 })
        #expect(analysis.spots.allSatisfy { $0.peopleSamples.count == $0.densitySamples.count })
        #expect(analysis.totalPeople == 200)
        #expect(analysis.simulatedPeople == 200)
    }

    @Test("Spots are numbered from 1 and sit inside the layout")
    func spotsInsideLayout() {
        let analysis = run()
        #expect(analysis.spots.count <= SpotSelector.maxSpots)
        #expect(analysis.spots.map(\.number) == Array(1...analysis.spots.count))
        for spot in analysis.spots {
            #expect(spot.position.x > 0 && spot.position.x < 24)
            #expect(spot.position.y > 0 && spot.position.y < 12)
        }
    }

    @Test("The same input and seed give the same result, another seed does not")
    func deterministic() {
        let layout = TestLayouts.hall()
        #expect(run(layout: layout, seed: 7) == run(layout: layout, seed: 7))
        #expect(run(layout: layout, seed: 7) != run(layout: layout, seed: 8))
    }

    @Test("People walk past the doors, and most of them leave before the event ends")
    func flowIsCounted() {
        let analysis = run()
        let total = analysis.flowPerMinute.reduce(0, +)
        #expect(total > 200)
        #expect(total <= 400)
    }

    @Test("More visitors make the floor more crowded")
    func visitorsRaiseDensity() {
        var few = TestLayouts.parameters
        few.totalVisitors = 100
        var many = TestLayouts.parameters
        many.totalVisitors = 2500
        #expect(peakDensity(run(parameters: many)) > peakDensity(run(parameters: few)))
    }

    @Test("A peak period brings more people past the doors")
    func peakPeriodRaisesFlow() {
        var base = TestLayouts.parameters
        base.totalVisitors = 1000
        var peaked = base
        peaked.peakPeriods = [TimeRange(startMinute: 11 * 60, endMinute: 12 * 60)]
        func flow(_ analysis: LayoutAnalysis) -> Double {
            analysis.flowPerMinute[60..<120].reduce(0, +)
        }
        #expect(flow(run(parameters: peaked)) > flow(run(parameters: base)) * 1.2)
    }

    @Test("Visitors who stay longer at booths crowd the floor more")
    func mixShapesCrowding() {
        let lingerers = [
            VisitorType(id: "a", name: "A", summary: "", walkingSpeedMps: 1.0, plannedStops: 6, dwellMinutes: 8),
            VisitorType(id: "b", name: "B", summary: "", walkingSpeedMps: 1.6, plannedStops: 1, dwellMinutes: 0.5)
        ]
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = 600
        parameters.mix = VisitorMix(shares: [.init(id: "a", percent: 100), .init(id: "b", percent: 0)])
        let slow = run(parameters: parameters, types: lingerers)
        parameters.mix = VisitorMix(shares: [.init(id: "a", percent: 0), .init(id: "b", percent: 100)])
        let quick = run(parameters: parameters, types: lingerers)
        #expect(peakDensity(slow) > peakDensity(quick))
    }

    @Test("Bigger groups put more people in one place")
    func groupSizeShapesCrowding() {
        var single = TestLayouts.parameters
        single.totalVisitors = 600
        single.groupSize = 1
        var large = single
        large.groupSize = 8
        let peopleAtOnce = { (analysis: LayoutAnalysis) in analysis.spots.flatMap(\.peopleSamples).max() ?? 0 }
        #expect(peopleAtOnce(run(parameters: large)) >= peopleAtOnce(run(parameters: single)))
        #expect(peakDensity(run(parameters: large)) > peakDensity(run(parameters: single)))
    }

    @Test("A layout with no floor gives an empty result and does not crash")
    func noFloor() {
        let empty = Layout(name: "Empty", sizeM: SIMD2(10, 10))
        let analysis = run(layout: empty)
        #expect(analysis.spots.isEmpty)
        #expect(analysis.flowPerMinute.allSatisfy { $0 == 0 })
    }

    @Test("A layout with no doors or markers still runs")
    func noDoors() {
        var layout = TestLayouts.hall()
        layout.markers = []
        layout.objects.removeAll { $0.kind == .door }
        let analysis = run(layout: layout)
        #expect(analysis.spots.isEmpty || analysis.flowPerMinute.allSatisfy { $0 == 0 })
    }

    @Test("The monitored spots are the busiest ones in the focus window")
    func focusWindow() {
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = 800
        parameters.peakPeriods = [TimeRange(startMinute: 12 * 60, endMinute: 13 * 60)]
        let analysis = run(parameters: parameters, focus: TimeRange(startMinute: 12 * 60, endMinute: 12 * 60 + 10))
        let window = (120 * 6)...(130 * 6)
        let windowPeak = analysis.spots.map { $0.densitySamples[window].max() ?? 0 }
        #expect(windowPeak.max() ?? 0 > 0)
        #expect(windowPeak == windowPeak.sorted(by: >))
    }
}

@MainActor
@Suite
struct CrowdSimulationReplayTests {
    private let focus = TimeRange(startMinute: 11 * 60, endMinute: 11 * 60 + 10)

    private func run(focus: TimeRange?, people: Int = 400) -> LayoutAnalysis {
        var parameters = TestLayouts.parameters
        parameters.totalVisitors = people
        return LayoutCrowdSimulation(input: SimulationInput(
            layout: TestLayouts.hall(),
            parameters: parameters,
            visitorTypes: TestLayouts.visitorTypes,
            focus: focus
        )).runToEnd()
    }

    @Test("The busiest window is recorded as a frame every 6 seconds")
    func frameCount() throws {
        let replay = try #require(run(focus: focus).replay)
        #expect(replay.startMinute == 660)
        #expect(replay.frameIntervalSeconds == 6)
        #expect(replay.frames.count == 101)
        #expect(replay.durationSeconds == 600)
    }

    @Test("Without a busiest window nothing is recorded")
    func noWindowNoReplay() {
        #expect(run(focus: nil).replay == nil)
    }

    @Test("Visitors stay on the floor and keep their id from frame to frame")
    func visitorsOnFloor() throws {
        let analysis = run(focus: focus)
        let replay = try #require(analysis.replay)
        let busy = try #require(replay.frames.last { !$0.visitors.isEmpty })
        #expect(Set(busy.visitors.map(\.id)).count == busy.visitors.count)
        for visitor in busy.visitors {
            #expect(visitor.position.x >= 0 && visitor.position.x <= 24)
            #expect(visitor.position.y >= 0 && visitor.position.y <= 12)
            #expect(visitor.people >= 1)
        }
        let persistent = Set(replay.frames[50].visitors.map(\.id)).intersection(replay.frames[51].visitors.map(\.id))
        #expect(!persistent.isEmpty)
    }

    @Test("Footfall only ever grows through the window")
    func footfallGrows() throws {
        let replay = try #require(run(focus: focus).replay)
        for (earlier, later) in zip(replay.frames, replay.frames.dropFirst()) {
            #expect(zip(earlier.footfall, later.footfall).allSatisfy { $0 <= $1 })
        }
        #expect((replay.frames.last?.footfall.max() ?? 0) > 0)
        #expect(replay.frames[0].footfall.count == replay.footfallColumns * replay.footfallRows)
    }

    @Test("The plan frame covers the floor, with the walkable mask on the same grid")
    func planAndMask() throws {
        let analysis = run(focus: focus)
        let replay = try #require(analysis.replay)
        #expect(analysis.plan.size.x > 24 && analysis.plan.size.y > 12)
        #expect(replay.walkable.origin == analysis.plan.origin)
        #expect(Double(replay.walkable.columns) * replay.walkable.cellSizeM == analysis.plan.size.x)
        #expect(replay.walkable.cells.contains(true) && replay.walkable.cells.contains(false))
    }

    @Test("The same input gives the same replay")
    func replayIsDeterministic() {
        let layout = TestLayouts.hall()
        func replay() -> SimulationReplay? {
            LayoutCrowdSimulation(input: SimulationInput(
                layout: layout, parameters: TestLayouts.parameters, visitorTypes: TestLayouts.visitorTypes, focus: focus
            )).runToEnd().replay
        }
        #expect(replay() == replay())
    }
}

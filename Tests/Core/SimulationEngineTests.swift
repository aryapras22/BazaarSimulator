import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("SimulationEngine Tests")
struct SimulationEngineTests {

    @Test("SimulationEngine spawns visitors and advances metrics deterministically")
    func engineSpawnsAndAdvancesDeterministically() {
        let layout = PreviewLayouts.smallMarket()
        let settings = SimulationSettings(
            totalVisitors: 100,
            arrivalsPer15Min: 300.0,
            randomSeed: 42
        )

        let engineA = SimulationEngine(layout: layout, settings: settings)
        let engineB = SimulationEngine(layout: layout, settings: settings)

        engineA.fastForward(minutes: 5)
        engineB.fastForward(minutes: 5)

        #expect(engineA.metrics.elapsedSeconds == 300.0)
        #expect(engineA.metrics.arrivals > 0)
        #expect(engineA.metrics == engineB.metrics)
        #expect(engineA.visitors.count == engineB.visitors.count)
    }

    @Test("SimulationEngine records simulation footage frames and heatmap cells")
    func engineRecordsSimulationFootageAndHeatmap() async {
        let layout = PreviewLayouts.smallMarket()
        let engine = SimulationEngine(layout: layout)

        let result = await engine.runWithRecordedFootage(durationMinutes: 3, frameIntervalSeconds: 10.0)

        #expect(result.layoutID == layout.id)
        #expect(!result.frames.isEmpty)
        #expect(!result.densityCells.isEmpty)
        #expect(result.metrics.arrivals > 0)

        let grade = SimulationAnalysis.grade(for: result.metrics.peakDensity)
        #expect(["A", "B", "C", "D", "E", "F"].contains(grade))
    }

    @Test("SimulationEngine reset clears visitors and metrics")
    func engineResetClearsState() {
        let layout = PreviewLayouts.smallMarket()
        let engine = SimulationEngine(layout: layout)

        engine.start()
        #expect(engine.isRunning)

        engine.fastForward(minutes: 3)
        #expect(engine.metrics.elapsedSeconds > 0)

        engine.reset()
        #expect(!engine.isRunning)
        #expect(engine.visitors.isEmpty)
        #expect(engine.metrics.elapsedSeconds == 0)
        #expect(engine.metrics.arrivals == 0)
    }

    @Test("VisitorShareBalancer always keeps total at 100%, respects locks, and incrementally fills unlocked types when reduced")
    func visitorShareBalancerRules() {
        // Reducing a slider at 100% incrementally distributes the freed percentage across the rest
        let reducedFromHundred = VisitorShareBalancer.adjust(
            shares: [100, 0, 0, 0],
            locked: [false, false, false, false],
            changedIndex: 0,
            newValue: 70
        )
        #expect(reducedFromHundred == [70, 10, 10, 10])
        #expect(reducedFromHundred.reduce(0, +) == 100)

        // Raising a slider scales down other unlocked sliders so total remains 100%
        let raised = VisitorShareBalancer.adjust(
            shares: [20, 40, 40, 0],
            locked: [false, false, false, false],
            changedIndex: 0,
            newValue: 60
        )
        #expect(raised[0] == 60)
        #expect(raised.reduce(0, +) == 100)

        // Locked slider never moves when another slider is raised or lowered
        let withLock = VisitorShareBalancer.adjust(
            shares: [20, 50, 30, 0],
            locked: [false, true, false, false],
            changedIndex: 0,
            newValue: 80
        )
        #expect(withLock[1] == 50)
        #expect(withLock[0] == 50)
        #expect(withLock[2] == 0)
        #expect(withLock.reduce(0, +) == 100)
    }

    @Test("Single visitor stays in Fruin Severity A (< 0.08 people/m²) and duration matches parameters")
    func singleVisitorStaysGradeAAndDurationMatches() async {
        let layout = PreviewLayouts.smallMarket()
        let params = EventParameters(
            totalVisitors: 1,
            startMinutes: 10 * 60,
            endMinutes: 14 * 60
        )
        let settings = params.toSimulationSettings()
        let engine = SimulationEngine(layout: layout, settings: settings)
        let result = await engine.runWithRecordedFootage(durationMinutes: settings.durationMinutes, frameIntervalSeconds: 30.0)

        #expect(result.durationSeconds == 14_400.0)
        #expect(result.frames.last?.elapsedSeconds == 14_400.0)
        #expect(result.metrics.arrivals == 1)
        #expect(result.metrics.peakDensity < 0.08)
        #expect(SimulationAnalysis.grade(for: result.metrics.peakDensity) == "A")
    }

    @Test("Arrivals follow the configured rate in people, whatever the party sizes")
    func arrivalsMatchConfiguredPeopleRate() {
        let settings = SimulationSettings(totalVisitors: 100_000, arrivalsPer15Min: 180.0, randomSeed: 42)
        let engine = SimulationEngine(layout: PreviewLayouts.smallMarket(), settings: settings)

        engine.fastForward(minutes: 60)

        #expect((612...828).contains(engine.metrics.arrivals))
    }

    @Test("Density cells add up to the number of people on the floor")
    func densityConservesPeople() {
        let engine = SimulationEngine(layout: Self.openFloor())
        engine.visitors = [
            SimulatedVisitor(id: 1, position: SIMD2<Double>(10.5, 10.5), peopleCount: 4)
        ]

        for _ in 0..<80 { engine.updateDensityCells() }

        let peopleOnFloor = engine.densityCells.reduce(0.0) { $0 + $1.peoplePerSquareMetre }
        #expect(abs(peopleOnFloor - 4.0) < 0.05)
    }

    @Test("Mean density still reflects the event after the hall empties")
    func meanDensitySurvivesEmptyHall() {
        let engine = SimulationEngine(layout: Self.openFloor())
        engine.visitors = [
            SimulatedVisitor(id: 1, position: SIMD2<Double>(10.5, 10.5), peopleCount: 4)
        ]
        for _ in 0..<20 { engine.updateDensityCells() }
        let meanWhileOccupied = engine.metrics.meanDensity

        engine.visitors = []
        for _ in 0..<80 { engine.updateDensityCells() }

        #expect(engine.densityCells.isEmpty)
        #expect(meanWhileOccupied > 0)
        #expect(engine.metrics.meanDensity > meanWhileOccupied * 0.5)
    }

    private static func openFloor() -> Layout {
        Layout(
            name: "Open floor",
            sizeM: SIMD2<Double>(20, 20),
            hall: [],
            lobby: [],
            objects: [],
            markers: [
                LayoutMarker(kind: .spawn, label: "In", position: SIMD2<Double>(2, 2)),
                LayoutMarker(kind: .exit, label: "Out", position: SIMD2<Double>(18, 2))
            ],
            zones: []
        )
    }
}

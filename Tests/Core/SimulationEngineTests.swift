import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("SimulationEngine Tests")
struct SimulationEngineTests {

    @Test("NavigationGrid builds walkable floor and carves doors")
    func navigationGridWalkableAndPaths() {
        let layout = PreviewLayouts.smallMarket()
        var grid = NavigationGrid(layout: layout)

        #expect(!grid.entrancePoints.isEmpty)
        #expect(!grid.exitPoints.isEmpty)

        // Door NW at (14, 20.1) should be carved as walkable
        let doorPoint = SIMD2<Double>(14.0, 20.1)
        #expect(grid.isWalkable(doorPoint))

        // Path from lobby spawn marker to a booth inside the hall should have waypoints
        let start = grid.entrancePoints[0]
        let boothCenter = SIMD2<Double>(8.0, 8.0)
        let path = grid.findPath(from: start, to: boothCenter)
        #expect(!path.isEmpty)
    }

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
    func engineRecordsSimulationFootageAndHeatmap() {
        let layout = PreviewLayouts.smallMarket()
        let engine = SimulationEngine(layout: layout)

        let result = engine.runWithRecordedFootage(durationMinutes: 3, frameIntervalSeconds: 10.0)

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

    @Test("VisitorShareBalancer caps total at 100%, respects locks, and only moves others on collision")
    func visitorShareBalancerRules() {
        // Lowering a slider below 100% does NOT move other unlocked sliders
        let lowered = VisitorShareBalancer.adjust(
            shares: [20, 40, 30, 10],
            locked: [false, false, false, false],
            changedIndex: 0,
            newValue: 5
        )
        #expect(lowered == [5, 40, 30, 10])

        // Raising a slider past 100% collides with ceiling and scales down other unlocked sliders
        let collided = VisitorShareBalancer.adjust(
            shares: [20, 40, 40, 0],
            locked: [false, false, false, false],
            changedIndex: 0,
            newValue: 60
        )
        #expect(collided[0] == 60)
        #expect(collided.reduce(0, +) == 100)

        // Locked slider never moves when another slider collides with 100%
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
    func singleVisitorStaysGradeAAndDurationMatches() {
        let layout = PreviewLayouts.smallMarket()
        let params = EventParameters(
            totalVisitors: 1,
            startMinutes: 10 * 60,
            endMinutes: 14 * 60
        )
        let settings = params.toSimulationSettings()
        let engine = SimulationEngine(layout: layout, settings: settings)
        let result = engine.runWithRecordedFootage(durationMinutes: settings.durationMinutes, frameIntervalSeconds: 30.0)

        #expect(result.durationSeconds == 14_400.0)
        #expect(result.frames.last?.elapsedSeconds == 14_400.0)
        #expect(result.metrics.arrivals == 1)
        #expect(result.metrics.peakDensity < 0.08)
        #expect(SimulationAnalysis.grade(for: result.metrics.peakDensity) == "A")
    }
}

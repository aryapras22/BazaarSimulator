import simd
import Testing
@testable import BazaarSimulator

@Suite
struct SimulationReplayTests {
    @Test("A point is placed as a share of the plan, kept inside it")
    func planFraction() {
        let plan = PlanFrame(origin: SIMD2(10, 20), size: SIMD2(40, 20))
        #expect(plan.fraction(of: SIMD2(30, 30)) == SIMD2(0.5, 0.5))
        #expect(plan.fraction(of: SIMD2(0, 0)) == SIMD2(0, 0))
        #expect(plan.fraction(of: SIMD2(100, 100)) == SIMD2(1, 1))
    }

    @Test("Coverage says how much of each coarse cell is floor")
    func coverage() {
        // 4 x 2 cells, the left half walkable.
        let mask = WalkableMask(
            origin: .zero, cellSizeM: 0.5, columns: 4, rows: 2,
            cells: [true, true, false, false, true, true, false, false]
        )
        #expect(mask.coverage(columns: 2, rows: 1) == [1, 0])
        #expect(mask.coverage(columns: 4, rows: 2) == [1, 1, 0, 0, 1, 1, 0, 0])
        #expect(mask.coverage(columns: 1, rows: 1) == [0.5])
    }

    @Test("The frame showing at a time is the last one that has started")
    func frameLookup() {
        let frames = (0..<3).map { index in
            SimulationReplay.Frame(
                visitors: [ReplayVisitor(id: index, position: .zero, typeIndex: 0, people: 1)], footfall: []
            )
        }
        let replay = SimulationReplay(
            startMinute: 0, frameIntervalSeconds: 6, frames: frames,
            walkable: WalkableMask(origin: .zero, cellSizeM: 0.5, columns: 1, rows: 1, cells: [true]),
            footfallColumns: 1, footfallRows: 1, footfallTileM: 1.5
        )
        #expect(replay.durationSeconds == 12)
        #expect(replay.frame(at: 0)?.visitors.first?.id == 0)
        #expect(replay.frame(at: 6.5)?.visitors.first?.id == 1)
        #expect(replay.frame(at: 999)?.visitors.first?.id == 2)
        #expect(replay.frame(at: -5)?.visitors.first?.id == 0)
    }
}

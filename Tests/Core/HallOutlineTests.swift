import simd
import Testing
@testable import BazaarSimulator

@Suite
struct HallOutlineTests {
    private func wall(from start: SIMD2<Double>, to end: SIMD2<Double>) -> LayoutObject {
        let size = simd_abs(end - start)
        return LayoutObject(
            kind: .wall,
            label: "Wall",
            placement: Placement(center: (start + end) / 2, sizeM: simd_max(size, SIMD2(repeating: 0.2)))
        )
    }

    private func booth(at center: SIMD2<Double>) -> LayoutObject {
        LayoutObject(kind: .booth, label: "A1", placement: Placement(center: center, sizeM: SIMD2(2, 2)))
    }

    private func door(at center: SIMD2<Double>, direction: DoorDirection = .both) -> LayoutObject {
        LayoutObject(
            kind: .door,
            label: "Door",
            placement: Placement(center: center, sizeM: SIMD2(2, 0.3)),
            doorFlow: DoorFlow(direction: direction)
        )
    }

    /// A 40 x 30 m hall over a lobby 10 m deep, with a short partition inside the hall.
    private var plan: [LayoutObject] {
        [
            wall(from: SIMD2(0, 0), to: SIMD2(40, 0)), wall(from: SIMD2(0, 0), to: SIMD2(0, 40)),
            wall(from: SIMD2(40, 0), to: SIMD2(40, 40)), wall(from: SIMD2(0, 40), to: SIMD2(40, 40)),
            wall(from: SIMD2(0, 30), to: SIMD2(18, 30)), wall(from: SIMD2(22, 30), to: SIMD2(40, 30)),
            wall(from: SIMD2(5, 20), to: SIMD2(15, 20)),
            booth(at: SIMD2(10, 10)), booth(at: SIMD2(30, 10)), booth(at: SIMD2(10, 25)), booth(at: SIMD2(30, 25))
        ]
    }

    @Test("The hall stops at the long wall that holds the open door, and the strip beyond it is the lobby")
    func hallStopsAtDoorWall() {
        let floor = HallOutline.floor(of: plan + [door(at: SIMD2(20, 30))])

        #expect(LayoutGeometry.bounds(of: floor.hall) == BoundingBox(minX: 0, maxX: 40, minY: 0, maxY: 30))
        // The lobby runs to the outer face of the outer walls, which are 0.2 m thick.
        #expect(LayoutGeometry.bounds(of: floor.lobby) == BoundingBox(minX: -0.1, maxX: 40.1, minY: 30, maxY: 40.1))
        #expect(floor.extent == SIMD2(40.1, 40.1))
    }

    @Test("A door drawn on the far face of a thick door wall still opens onto a lobby")
    func doorBeyondThickWall() {
        let floor = HallOutline.floor(of: plan + [door(at: SIMD2(20, 33))])

        #expect(LayoutGeometry.bounds(of: floor.lobby).minY == 30)
    }

    @Test("A side with no open door gets no lobby")
    func closedDoorMakesNoLobby() {
        let floor = HallOutline.floor(of: plan + [door(at: SIMD2(20, 30), direction: .disabled)])

        #expect(floor.lobby.isEmpty)
    }
}

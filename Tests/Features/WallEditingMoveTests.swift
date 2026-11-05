import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct WallEditingMoveTests {
    private static func makeWall(
        start: SIMD2<Double>,
        end: SIMD2<Double>,
        thickness: Double = 0.2
    ) -> LayoutObject {
        let vector = end - start
        let length = simd_length(vector)
        let center = (start + end) / 2.0
        let rotation = atan2(vector.y, vector.x)
        return LayoutObject(
            id: UUID(),
            kind: .wall,
            label: "Wall",
            placement: Placement(
                center: center,
                sizeM: SIMD2<Double>(length, thickness),
                rotationRadians: rotation
            ),
            catalogID: "wall",
            heightM: 3.0
        )
    }

    private static func makeLayout(objects: [LayoutObject]) -> Layout {
        Layout(
            name: "Test",
            sizeM: SIMD2<Double>(40, 40),
            hall: [
                SIMD2<Double>(0, 0),
                SIMD2<Double>(30, 0),
                SIMD2<Double>(30, 30),
                SIMD2<Double>(0, 30)
            ],
            objects: objects
        )
    }

    @Test("setWallLength moves far end and stretches incident neighbours")
    func setWallLengthStretchesFarEndAndNeighbours() throws {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let layout = Self.makeLayout(objects: [wall1, wall2])
        let graph = WallGraph(layout: layout)

        let editStartAnchor = WallEditing.setWallLength(
            wall: wall1,
            newLength: 15.0,
            anchor: .start,
            in: layout,
            graph: graph
        )
        let updatedStart = LayoutEditing.apply(editStartAnchor, to: layout)
        let graphStart = WallGraph(layout: updatedStart)
        let ep1Start = try #require(graphStart.endpoints(for: wall1.id))
        let ep2Start = try #require(graphStart.endpoints(for: wall2.id))
        #expect(simd_distance(ep1Start.start, SIMD2<Double>(0, 0)) < 0.05)
        #expect(simd_distance(ep1Start.end, SIMD2<Double>(15, 0)) < 0.05)
        #expect(simd_distance(ep2Start.start, SIMD2<Double>(15, 0)) < 0.05)
        #expect(simd_distance(ep2Start.end, SIMD2<Double>(10, 8)) < 0.05)

        let editEndAnchor = WallEditing.setWallLength(
            wall: wall1,
            newLength: 12.0,
            anchor: .end,
            in: layout,
            graph: graph
        )
        let updatedEnd = LayoutEditing.apply(editEndAnchor, to: layout)
        let graphEnd = WallGraph(layout: updatedEnd)
        let ep1End = try #require(graphEnd.endpoints(for: wall1.id))
        let ep2End = try #require(graphEnd.endpoints(for: wall2.id))
        #expect(simd_distance(ep1End.start, SIMD2<Double>(-2, 0)) < 0.05)
        #expect(simd_distance(ep1End.end, SIMD2<Double>(10, 0)) < 0.05)
        #expect(simd_distance(ep2End.start, SIMD2<Double>(10, 0)) < 0.05)
    }
}

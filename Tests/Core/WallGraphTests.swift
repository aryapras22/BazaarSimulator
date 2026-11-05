import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct WallGraphTests {
    private static func makeWall(
        id: UUID = UUID(),
        start: SIMD2<Double>,
        end: SIMD2<Double>,
        thickness: Double = 0.2
    ) -> LayoutObject {
        let vector = end - start
        let length = simd_length(vector)
        let center = (start + end) / 2.0
        let rotation = atan2(vector.y, vector.x)
        return LayoutObject(
            id: id,
            kind: .wall,
            label: "Wall",
            placement: Placement(
                center: center,
                sizeM: SIMD2<Double>(length, thickness),
                rotationRadians: rotation
            )
        )
    }

    @Test("Shared ends merge into one node with incident walls as neighbours")
    func sharedEnds() {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let graph = WallGraph(walls: [wall1, wall2])

        #expect(graph.nodes.count == 3)
        let junction = graph.nearestNode(to: SIMD2<Double>(10, 0), maximumDistance: 0.01)
        #expect(junction != nil)
        #expect(junction?.isTNode == false)
        #expect(junction?.wallIDs == [wall1.id, wall2.id])
        #expect(graph.neighbours(of: wall1.id) == [wall2.id])
        #expect(graph.neighbours(of: wall2.id) == [wall1.id])
    }

    @Test("T contact creates a T node and links through-wall as neighbour")
    func tContact() {
        let hostWall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let stemWall = Self.makeWall(start: SIMD2<Double>(5, 5), end: SIMD2<Double>(5, 0.02))
        let graph = WallGraph(walls: [hostWall, stemWall])

        let tNode = graph.nodes.first { $0.isTNode }
        #expect(tNode != nil)
        #expect(tNode?.wallIDs == [hostWall.id, stemWall.id])
        #expect(tNode?.incidents.contains { $0.wallID == hostWall.id && $0.end == .body } == true)
        #expect(tNode?.incidents.contains { $0.wallID == stemWall.id && $0.end == .end } == true)
        #expect(graph.neighbours(of: hostWall.id).contains(stemWall.id))
        #expect(graph.neighbours(of: stemWall.id).contains(hostWall.id))
    }

    @Test("Near misses beyond tolerance stay separate and do not become neighbours")
    func nearMisses() {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(4.92, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(5.00, 0), end: SIMD2<Double>(10.00, 0))
        let stemWall = Self.makeWall(start: SIMD2<Double>(8, 5), end: SIMD2<Double>(8, 0.08))

        let graph = WallGraph(walls: [wall1, wall2, stemWall])
        #expect(graph.neighbours(of: wall1.id).isEmpty)
        #expect(graph.neighbours(of: wall2.id).isEmpty)
        #expect(graph.neighbours(of: stemWall.id).isEmpty)
        #expect(graph.nodes.allSatisfy { !$0.isTNode })
    }

    @Test("Long chain of five walls produces six nodes with correct neighbour connectivity")
    func longChain() {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(2, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(2, 0), end: SIMD2<Double>(4, 0))
        let wall3 = Self.makeWall(start: SIMD2<Double>(4, 0), end: SIMD2<Double>(6, 0))
        let wall4 = Self.makeWall(start: SIMD2<Double>(6, 0), end: SIMD2<Double>(8, 0))
        let wall5 = Self.makeWall(start: SIMD2<Double>(8, 0), end: SIMD2<Double>(10, 0))

        let graph = WallGraph(walls: [wall1, wall2, wall3, wall4, wall5])
        #expect(graph.nodes.count == 6)
        #expect(graph.neighbours(of: wall1.id) == [wall2.id])
        #expect(graph.neighbours(of: wall2.id) == [wall1.id, wall3.id])
        #expect(graph.neighbours(of: wall3.id) == [wall2.id, wall4.id])
        #expect(graph.neighbours(of: wall4.id) == [wall3.id, wall5.id])
        #expect(graph.neighbours(of: wall5.id) == [wall4.id])
    }

    @Test("Closed rectangular room produces four shared nodes")
    func closedLoop() {
        let south = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(6, 0))
        let east = Self.makeWall(start: SIMD2<Double>(6, 0), end: SIMD2<Double>(6, 4))
        let north = Self.makeWall(start: SIMD2<Double>(6, 4), end: SIMD2<Double>(0, 4))
        let west = Self.makeWall(start: SIMD2<Double>(0, 4), end: SIMD2<Double>(0, 0))

        let graph = WallGraph(walls: [south, east, north, west])
        #expect(graph.nodes.count == 4)
        #expect(graph.nodes.allSatisfy { $0.incidents.count == 2 })
        #expect(graph.neighbours(of: south.id) == [east.id, west.id])
        #expect(graph.neighbours(of: north.id) == [east.id, west.id])
    }

    @Test("Custom tolerance bridges gaps larger than default")
    func customTolerance() {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(4.92, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(5.00, 0), end: SIMD2<Double>(10.00, 0))

        let strictGraph = WallGraph(walls: [wall1, wall2], tolerance: 0.05)
        #expect(strictGraph.nodes.count == 4)

        let looseGraph = WallGraph(walls: [wall1, wall2], tolerance: 0.10)
        #expect(looseGraph.nodes.count == 3)
        #expect(looseGraph.neighbours(of: wall1.id) == [wall2.id])
    }
}

import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct WallEditingTests {
    private static func makeWall(
        id: UUID = UUID(),
        start: SIMD2<Double>,
        end: SIMD2<Double>,
        thickness: Double = 0.2,
        catalogID: String = "wall",
        heightM: Double = 3.0
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
            ),
            catalogID: catalogID,
            heightM: heightM
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

    @Test("Splitting a wall keeps total length, thickness, catalog ID, height, and first ID")
    func splitWallPreservesAttributes() throws {
        let wall = Self.makeWall(
            start: SIMD2<Double>(0, 0),
            end: SIMD2<Double>(10, 0),
            thickness: 0.25,
            catalogID: "custom-wall",
            heightM: 2.8
        )
        let layout = Self.makeLayout(objects: [wall])

        let edit = WallEditing.split(wall: wall, at: SIMD2<Double>(4, 0), in: layout)
        let updated = LayoutEditing.apply(edit, to: layout)

        #expect(updated.objects.count == 2)
        let firstHalf = try #require(updated.objects.first { $0.id == wall.id })
        let secondHalf = try #require(updated.objects.first { $0.id != wall.id })

        let totalLength = firstHalf.placement.sizeM.x + secondHalf.placement.sizeM.x
        #expect(abs(totalLength - 10.0) < 0.001)
        #expect(abs(firstHalf.placement.sizeM.x - 4.0) < 0.001)
        #expect(abs(secondHalf.placement.sizeM.x - 6.0) < 0.001)

        #expect(firstHalf.placement.sizeM.y == 0.25)
        #expect(secondHalf.placement.sizeM.y == 0.25)
        #expect(firstHalf.catalogID == "custom-wall")
        #expect(secondHalf.catalogID == "custom-wall")
        #expect(firstHalf.heightM == 2.8)
        #expect(secondHalf.heightM == 2.8)

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: edit), to: updated)
        #expect(reverted.objects.count == 1)
        #expect(reverted.objects.first?.placement == wall.placement)
    }

    @Test("Door split through its span stays on the wall half holding its center")
    func doorStaysOnWallHoldingCenter() throws {
        let wall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let door = LayoutObject(
            id: UUID(),
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2<Double>(5.2, 0), sizeM: SIMD2<Double>(2.0, 0.2)),
            doorFlow: DoorFlow(direction: .both, connection: .hallToOutside)
        )
        let layout = Self.makeLayout(objects: [wall, door])

        let edit = WallEditing.split(wall: wall, at: SIMD2<Double>(5.0, 0), in: layout)
        let updated = LayoutEditing.apply(edit, to: layout)

        let secondHalf = try #require(updated.objects.first { $0.kind == LayoutObjectKind.wall && $0.id != wall.id })
        let nearestHost = try #require(DoorHosting.nearestHost(to: door.placement.center, in: updated))

        let secondHalfHalfL = secondHalf.placement.sizeM.x / 2.0
        let secondHalfStart = LayoutGeometry.toWorld(
            local: SIMD2<Double>(-secondHalfHalfL, 0),
            in: secondHalf.placement
        )
        let secondHalfEnd = LayoutGeometry.toWorld(
            local: SIMD2<Double>(secondHalfHalfL, 0),
            in: secondHalf.placement
        )

        #expect(simd_distance(nearestHost.start, secondHalfStart) < 0.01)
        #expect(simd_distance(nearestHost.end, secondHalfEnd) < 0.01)
    }

    @Test("Moving a node stretches only incident walls at that node")
    func moveNodeStretchesIncidentWalls() throws {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let wall3 = Self.makeWall(start: SIMD2<Double>(20, 0), end: SIMD2<Double>(20, 5))
        let layout = Self.makeLayout(objects: [wall1, wall2, wall3])
        let graph = WallGraph(layout: layout)

        let sharedNode = try #require(graph.nearestNode(to: SIMD2<Double>(10, 0), maximumDistance: 0.01))
        let edit = WallEditing.moveNode(nodeID: sharedNode.id, to: SIMD2<Double>(12, 2), in: layout, graph: graph)
        let updated = LayoutEditing.apply(edit, to: layout)

        let updated1 = try #require(updated.objects.first { $0.id == wall1.id })
        let updated2 = try #require(updated.objects.first { $0.id == wall2.id })
        let updated3 = try #require(updated.objects.first { $0.id == wall3.id })

        let graphAfter = WallGraph(layout: updated)
        let endpoints1 = try #require(graphAfter.endpoints(for: updated1.id))
        let endpoints2 = try #require(graphAfter.endpoints(for: updated2.id))

        #expect(simd_distance(endpoints1.start, SIMD2<Double>(0, 0)) < 0.01)
        #expect(simd_distance(endpoints1.end, SIMD2<Double>(12, 2)) < 0.01)
        #expect(simd_distance(endpoints2.start, SIMD2<Double>(12, 2)) < 0.01)
        #expect(simd_distance(endpoints2.end, SIMD2<Double>(10, 8)) < 0.01)
        #expect(updated3.placement == wall3.placement)
    }

    @Test("Detaching a wall at a node moves only the detached wall")
    func detachWallOnlyMovesTarget() throws {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let layout = Self.makeLayout(objects: [wall1, wall2])
        let graph = WallGraph(layout: layout)

        let sharedNode = try #require(graph.nearestNode(to: SIMD2<Double>(10, 0), maximumDistance: 0.01))
        let edit = WallEditing.detach(
            wallID: wall1.id,
            at: sharedNode.id,
            to: SIMD2<Double>(10, -2),
            in: layout,
            graph: graph
        )
        let updated = LayoutEditing.apply(edit, to: layout)

        let graphAfter = WallGraph(layout: updated)
        let endpoints1 = try #require(graphAfter.endpoints(for: wall1.id))
        let endpoints2 = try #require(graphAfter.endpoints(for: wall2.id))

        #expect(simd_distance(endpoints1.end, SIMD2<Double>(10, -2)) < 0.01)
        #expect(simd_distance(endpoints2.start, SIMD2<Double>(10, 0)) < 0.01)
        #expect(graphAfter.neighbours(of: wall1.id).isEmpty)
    }

    @Test("Bending midpoint splits wall into two angled segments meeting at pointer")
    func bendMidpointSplitsAndBends() throws {
        let wall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let layout = Self.makeLayout(objects: [wall])

        let edit = WallEditing.bendMidpoint(wall: wall, to: SIMD2<Double>(5, 4), in: layout)
        let updated = LayoutEditing.apply(edit, to: layout)

        #expect(updated.objects.count == 2)
        let graphAfter = WallGraph(layout: updated)
        #expect(graphAfter.nodes.count == 3)

        let cornerNode = try #require(graphAfter.nearestNode(to: SIMD2<Double>(5, 4), maximumDistance: 0.01))
        #expect(cornerNode.incidents.count == 2)

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: edit), to: updated)
        #expect(reverted.objects.count == 1)
        #expect(reverted.objects.first?.placement == wall.placement)
    }

    @Test("Starting a chain on a wall body splits host and undo restores one wall")
    func chainStartingOnWallBodySplitsHost() throws {
        let wall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let layout = Self.makeLayout(objects: [wall])

        let points = [SIMD2<Double>(5, 0), SIMD2<Double>(5, 6)]
        let plan = WallEditing.planChainCommit(
            points: points,
            attributes: WallEditing.WallAttributes(),
            in: layout
        )
        let updated = LayoutEditing.apply(plan.edit, to: layout)

        #expect(updated.objects.count == 3)
        let graphAfter = WallGraph(layout: updated)
        let junction = try #require(graphAfter.nearestNode(to: SIMD2<Double>(5, 0), maximumDistance: 0.01))
        #expect(junction.incidents.count == 3)
        #expect(junction.isTNode == false)

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: plan.edit), to: updated)
        #expect(reverted.objects.count == 1)
        #expect(reverted.objects.first?.placement == wall.placement)
    }

    @Test("Ending a chain on a wall body splits host wall")
    func chainEndingOnWallBodySplitsHost() throws {
        let wallA = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wallB = Self.makeWall(start: SIMD2<Double>(0, 10), end: SIMD2<Double>(10, 10))
        let layout = Self.makeLayout(objects: [wallA, wallB])

        let points = [SIMD2<Double>(5, 0), SIMD2<Double>(5, 10)]
        let plan = WallEditing.planChainCommit(
            points: points,
            attributes: WallEditing.WallAttributes(),
            in: layout
        )
        let updated = LayoutEditing.apply(plan.edit, to: layout)

        #expect(updated.objects.count == 5) // 2 from wallA + 2 from wallB + 1 connecting wall

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: plan.edit), to: updated)
        #expect(reverted.objects.count == 2)
    }

    @Test("A chain crossing a wall splits both at the crossing")
    func chainCrossingWallSplitsBoth() throws {
        let wall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let layout = Self.makeLayout(objects: [wall])

        let plan = WallEditing.planChainCommit(
            points: [SIMD2<Double>(5, -4), SIMD2<Double>(5, 4)],
            attributes: WallEditing.WallAttributes(),
            in: layout
        )
        let updated = LayoutEditing.apply(plan.edit, to: layout)

        #expect(updated.objects.count == 4)
        let graph = WallGraph(layout: updated)
        let junction = try #require(graph.nearestNode(to: SIMD2<Double>(5, 0), maximumDistance: 0.01))
        #expect(junction.incidents.count == 4)

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: plan.edit), to: updated)
        #expect(reverted.objects.count == 1)
    }

    @Test("Closing on first node creates closed loop and inserts all segments")
    func closedLoopInsertsAllSegments() {
        let layout = Self.makeLayout(objects: [])
        let points = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(10, 0),
            SIMD2<Double>(10, 8),
            SIMD2<Double>(0, 8),
            SIMD2<Double>(0, 0)
        ]
        let plan = WallEditing.planChainCommit(
            points: points,
            attributes: WallEditing.WallAttributes(),
            in: layout
        )
        let updated = LayoutEditing.apply(plan.edit, to: layout)

        #expect(updated.objects.count == 4)
        let graphAfter = WallGraph(layout: updated)
        #expect(graphAfter.nodes.count == 4)
        #expect(graphAfter.nodes.allSatisfy { $0.incidents.count == 2 })

        let reverted = LayoutEditing.apply(LayoutEditing.inverse(of: plan.edit), to: updated)
        #expect(reverted.objects.isEmpty)
    }

    @Test("Typed distance from nearest end places dot on host wall centerline")
    func typedDistanceFromNearestEndPlacesDotOnWall() throws {
        let wall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let layout = Self.makeLayout(objects: [wall])

        let pointNearStart = try #require(WallEditing.pointOnHostWall(
            snapped: SIMD2<Double>(2, 0),
            distanceFromNearEnd: 3.0,
            in: layout
        ))
        #expect(abs(pointNearStart.x - 3.0) < 1e-4)
        #expect(abs(pointNearStart.y - 0.0) < 1e-4)

        let pointNearEnd = try #require(WallEditing.pointOnHostWall(
            snapped: SIMD2<Double>(9, 0),
            distanceFromNearEnd: 2.0,
            in: layout
        ))
        #expect(abs(pointNearEnd.x - 8.0) < 1e-4)
        #expect(abs(pointNearEnd.y - 0.0) < 1e-4)
    }
}

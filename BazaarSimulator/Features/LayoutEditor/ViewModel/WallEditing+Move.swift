import Foundation
import simd

extension WallEditing {
    struct WallEndUpdate {
        var newStart: SIMD2<Double>?
        var newEnd: SIMD2<Double>?
    }

    private static func updateNeighbor(
        incident: WallGraph.Incident,
        targetPos: SIMD2<Double>,
        updates: inout [UUID: WallEndUpdate]
    ) {
        guard incident.end != .body else { return }
        var current = updates[incident.wallID, default: WallEndUpdate()]
        if incident.end == .start {
            current.newStart = targetPos
        } else if incident.end == .end {
            current.newEnd = targetPos
        }
        updates[incident.wallID] = current
    }

    private static func collectNeighborUpdates(
        for wall: LayoutObject,
        delta: SIMD2<Double>,
        graph: WallGraph
    ) -> [UUID: WallEndUpdate] {
        guard let endpoints = graph.endpoints(for: wall.id) else { return [:] }
        let newStart = endpoints.start + delta
        let newEnd = endpoints.end + delta

        var updates: [UUID: WallEndUpdate] = [:]
        if let startNode = graph.node(for: wall.id, end: .start) {
            for incident in startNode.incidents where incident.wallID != wall.id {
                updateNeighbor(incident: incident, targetPos: newStart, updates: &updates)
            }
        }
        if let endNode = graph.node(for: wall.id, end: .end) {
            for incident in endNode.incidents where incident.wallID != wall.id {
                updateNeighbor(incident: incident, targetPos: newEnd, updates: &updates)
            }
        }
        return updates
    }

    private static func applyNeighborUpdates(
        _ updates: [UUID: WallEndUpdate],
        in layout: Layout
    ) -> [LayoutEdit] {
        var edits: [LayoutEdit] = []
        for (wallID, update) in updates {
            guard let otherWall = layout.objects.first(where: { $0.id == wallID }) else {
                continue
            }
            let halfL = otherWall.placement.sizeM.x / 2.0
            let currentStart = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: otherWall.placement)
            let currentEnd = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: otherWall.placement)
            let updatedStart = update.newStart ?? currentStart
            let updatedEnd = update.newEnd ?? currentEnd
            let updatedWall = makeSegment(
                id: otherWall.id,
                from: updatedStart,
                to: updatedEnd,
                thickness: otherWall.placement.sizeM.y,
                template: otherWall
            )
            edits.append(.replace(before: otherWall, after: updatedWall))
        }
        return edits
    }

    private static func moveHostedDoors(
        on wall: LayoutObject,
        delta: SIMD2<Double>,
        in layout: Layout
    ) -> [LayoutEdit] {
        let halfL = wall.placement.sizeM.x / 2.0
        let halfT = wall.placement.sizeM.y / 2.0 + 0.15
        var edits: [LayoutEdit] = []
        for object in layout.objects where object.kind == .door {
            let local = LayoutGeometry.toLocal(point: object.placement.center, in: wall.placement)
            if abs(local.x) <= halfL && abs(local.y) <= halfT {
                var movedDoor = object
                movedDoor.placement.center += delta
                edits.append(.replace(before: object, after: movedDoor))
            }
        }
        return edits
    }

    static func moveWallWithNeighbours(
        wall: LayoutObject,
        delta: SIMD2<Double>,
        in layout: Layout,
        graph: WallGraph
    ) -> LayoutEdit {
        var movedWall = wall
        movedWall.placement.center += delta

        var edits: [LayoutEdit] = [.replace(before: wall, after: movedWall)]
        let neighborUpdates = collectNeighborUpdates(for: wall, delta: delta, graph: graph)
        edits.append(contentsOf: applyNeighborUpdates(neighborUpdates, in: layout))
        edits.append(contentsOf: moveHostedDoors(on: wall, delta: delta, in: layout))
        return .batch(edits)
    }
}

import Foundation
import simd

enum WallEditing {
    static func split(
        wall: LayoutObject,
        at point: SIMD2<Double>,
        in layout: Layout
    ) -> LayoutEdit {
        let halfL = wall.placement.sizeM.x / 2.0
        let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
        let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)

        let local = LayoutGeometry.toLocal(point: point, in: wall.placement)
        let clampedX = min(max(local.x, -halfL + 0.01), halfL - 0.01)
        let splitPoint = LayoutGeometry.toWorld(local: SIMD2<Double>(clampedX, 0), in: wall.placement)

        let thickness = wall.placement.sizeM.y
        let firstHalf = makeSegment(id: wall.id, from: start, to: splitPoint, thickness: thickness, template: wall)
        let secondHalf = makeSegment(id: UUID(), from: splitPoint, to: end, thickness: thickness, template: wall)

        let wallIndex = layout.objects.firstIndex(where: { $0.id == wall.id }) ?? layout.objects.count
        return .batch([
            .replace(before: wall, after: firstHalf),
            .insert(secondHalf, index: wallIndex + 1)
        ])
    }

    static func bendMidpoint(
        wall: LayoutObject,
        to newPosition: SIMD2<Double>,
        in layout: Layout
    ) -> LayoutEdit {
        let halfL = wall.placement.sizeM.x / 2.0
        let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
        let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
        let thickness = wall.placement.sizeM.y

        let segment1 = makeSegment(id: wall.id, from: start, to: newPosition, thickness: thickness, template: wall)
        let segment2 = makeSegment(id: UUID(), from: newPosition, to: end, thickness: thickness, template: wall)

        let wallIndex = layout.objects.firstIndex(where: { $0.id == wall.id }) ?? layout.objects.count
        return .batch([
            .replace(before: wall, after: segment1),
            .insert(segment2, index: wallIndex + 1)
        ])
    }

    static func moveNode(
        nodeID: UUID,
        to newPosition: SIMD2<Double>,
        in layout: Layout,
        graph: WallGraph
    ) -> LayoutEdit {
        guard let node = graph.node(at: nodeID) else {
            return .batch([])
        }
        var edits: [LayoutEdit] = []
        for incident in node.incidents where incident.end != .body {
            guard let wall = layout.objects.first(where: { $0.id == incident.wallID }) else {
                continue
            }
            let halfL = wall.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
            let thickness = wall.placement.sizeM.y

            let updated: LayoutObject
            if incident.end == .start {
                updated = makeSegment(id: wall.id, from: newPosition, to: end, thickness: thickness, template: wall)
            } else {
                updated = makeSegment(id: wall.id, from: start, to: newPosition, thickness: thickness, template: wall)
            }
            edits.append(.replace(before: wall, after: updated))
        }
        return .batch(edits)
    }

    static func detach(
        wallID: UUID,
        at nodeID: UUID,
        to newPosition: SIMD2<Double>,
        in layout: Layout,
        graph: WallGraph
    ) -> LayoutEdit {
        guard let node = graph.node(at: nodeID),
              let incident = node.incidents.first(where: { $0.wallID == wallID && $0.end != .body }),
              let wall = layout.objects.first(where: { $0.id == wallID }) else {
            return .batch([])
        }
        let halfL = wall.placement.sizeM.x / 2.0
        let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement)
        let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
        let thickness = wall.placement.sizeM.y

        let updated: LayoutObject
        if incident.end == .start {
            updated = makeSegment(id: wall.id, from: newPosition, to: end, thickness: thickness, template: wall)
        } else {
            updated = makeSegment(id: wall.id, from: start, to: newPosition, thickness: thickness, template: wall)
        }
        return .batch([.replace(before: wall, after: updated)])
    }

    private static func makeSegment(
        id: UUID,
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        thickness: Double,
        template: LayoutObject
    ) -> LayoutObject {
        let vector = end - start
        let length = simd_length(vector)
        let center = (start + end) / 2.0
        let rotation = atan2(vector.y, vector.x)
        return LayoutObject(
            id: id,
            kind: .wall,
            label: template.label,
            placement: Placement(
                center: center,
                sizeM: SIMD2<Double>(max(length, 0.001), thickness),
                rotationRadians: rotation
            ),
            catalogID: template.catalogID,
            heightM: template.heightM
        )
    }
}

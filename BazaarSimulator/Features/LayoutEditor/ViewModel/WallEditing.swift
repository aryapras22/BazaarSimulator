import Foundation
import simd

enum WallEditing {
    struct WallAttributes: Sendable {
        let kind: LayoutObjectKind
        let thickness: Double
        let height: Double
        let catalogID: String

        init(
            kind: LayoutObjectKind = .wall,
            thickness: Double = 0.2,
            height: Double = 3.0,
            catalogID: String = "wall"
        ) {
            self.kind = kind
            self.thickness = thickness
            self.height = height
            self.catalogID = catalogID
        }
    }

    static func findHostWall(
        at point: SIMD2<Double>,
        in layout: Layout,
        tolerance: Double = 0.05
    ) -> LayoutObject? {
        for object in layout.objects where object.kind == .wall {
            let halfL = object.placement.sizeM.x / 2.0
            let local = LayoutGeometry.toLocal(point: point, in: object.placement)
            let isInterior = local.x > -halfL + tolerance && local.x < halfL - tolerance
            let isNearCenterline = abs(local.y) <= tolerance
            if isInterior && isNearCenterline {
                return object
            }
        }
        return nil
    }

    static func pointOnHostWall(
        snapped: SIMD2<Double>,
        distanceFromNearEnd: Double,
        in layout: Layout,
        tolerance: Double = 0.1
    ) -> SIMD2<Double>? {
        for object in layout.objects where object.kind == .wall {
            let halfL = object.placement.sizeM.x / 2.0
            let local = LayoutGeometry.toLocal(point: snapped, in: object.placement)
            let isAlongLength = local.x >= -halfL - tolerance && local.x <= halfL + tolerance
            let isNearCenterline = abs(local.y) <= tolerance
            if isAlongLength && isNearCenterline {
                let endA = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: object.placement)
                let endB = LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: object.placement)
                let distA = simd_distance(snapped, endA)
                let distB = simd_distance(snapped, endB)
                let nearEnd = distA < distB ? endA : endB
                let farEnd = distA < distB ? endB : endA
                let wallLength = object.placement.sizeM.x
                guard wallLength > 1e-6 else { return nearEnd }
                let dir = simd_normalize(farEnd - nearEnd)
                let clampedDistance = min(max(distanceFromNearEnd, 0), wallLength)
                return nearEnd + dir * clampedDistance
            }
        }
        return nil
    }

    static func planChainCommit(
        points: [SIMD2<Double>],
        attributes: WallAttributes,
        in layout: Layout
    ) -> (edit: LayoutEdit, createdWallIDs: [UUID]) {
        guard points.count >= 2 else {
            return (.batch([]), [])
        }
        var workingLayout = layout
        var batchEdits: [LayoutEdit] = []

        if let first = points.first, let host = findHostWall(at: first, in: workingLayout) {
            let splitEdit = split(wall: host, at: first, in: workingLayout)
            batchEdits.append(splitEdit)
            workingLayout = LayoutEditing.apply(splitEdit, to: workingLayout)
        }

        let isClosed = points.count >= 3 && simd_distance(points.first!, points.last!) < 1e-4
        if !isClosed, let last = points.last, let host = findHostWall(at: last, in: workingLayout) {
            let splitEdit = split(wall: host, at: last, in: workingLayout)
            batchEdits.append(splitEdit)
            workingLayout = LayoutEditing.apply(splitEdit, to: workingLayout)
        }

        let newWalls = buildChainSegments(points: points, attributes: attributes)
        let baseIndex = workingLayout.objects.count
        for (offset, newWall) in newWalls.enumerated() {
            batchEdits.append(.insert(newWall, index: baseIndex + offset))
        }

        return (.batch(batchEdits), newWalls.map(\.id))
    }

    private static func buildChainSegments(
        points: [SIMD2<Double>],
        attributes: WallAttributes
    ) -> [LayoutObject] {
        var newWalls: [LayoutObject] = []
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let vector = end - start
            let length = simd_length(vector)
            guard length > 1e-6 else { continue }
            let center = (start + end) / 2.0
            let rotation = atan2(vector.y, vector.x)
            let newWall = LayoutObject(
                id: UUID(),
                kind: attributes.kind,
                label: "Wall",
                placement: Placement(
                    center: center,
                    sizeM: SIMD2<Double>(max(length, 0.001), attributes.thickness),
                    rotationRadians: rotation
                ),
                catalogID: attributes.catalogID,
                heightM: attributes.height
            )
            newWalls.append(newWall)
        }
        return newWalls
    }

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

    static func makeSegment(
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

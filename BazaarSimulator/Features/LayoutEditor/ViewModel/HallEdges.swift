import Foundation
import simd

struct LayoutOutline: Equatable, Sendable {
    var hall: [SIMD2<Double>]
    var sizeM: SIMD2<Double>
    var lobby: [SIMD2<Double>]?
    var markers: [LayoutMarker]?
    var zones: [LayoutZone]?

    init(
        hall: [SIMD2<Double>],
        sizeM: SIMD2<Double>,
        lobby: [SIMD2<Double>]? = nil,
        markers: [LayoutMarker]? = nil,
        zones: [LayoutZone]? = nil
    ) {
        self.hall = hall
        self.sizeM = sizeM
        self.lobby = lobby
        self.markers = markers
        self.zones = zones
    }

    init(layout: Layout) {
        self.hall = layout.hall
        self.sizeM = layout.sizeM
        self.lobby = layout.lobby
        self.markers = layout.markers
        self.zones = layout.zones
    }
}

struct HallEdgeMove: Sendable {
    let edit: LayoutEdit
    let hall: [SIMD2<Double>]
    let doorPlacements: [UUID: Placement]
}

enum HallEdges {
    static let snapCellM = 0.25
    private static let epsilon = 1e-6

    static func midpoint(of edge: Int, in hall: [SIMD2<Double>]) -> SIMD2<Double> {
        (hall[edge] + hall[(edge + 1) % hall.count]) / 2.0
    }

    static func edge(near point: SIMD2<Double>, in hall: [SIMD2<Double>], within toleranceM: Double) -> Int? {
        guard hall.count >= 3 else { return nil }
        return hall.indices
            .map { (edge: $0, distance: simd_distance(midpoint(of: $0, in: hall), point)) }
            .filter { $0.distance <= toleranceM }
            .min { $0.distance < $1.distance }?
            .edge
    }

    static func isSplitVertex(at index: Int, in hall: [SIMD2<Double>]) -> Bool {
        guard hall.count >= 3, hall.indices.contains(index) else { return false }
        let prev = hall[(index - 1 + hall.count) % hall.count]
        let curr = hall[index]
        let next = hall[(index + 1) % hall.count]
        return areCollinearSameDirection(prev, curr, next)
    }

    static func split(at point: SIMD2<Double>, in layout: Layout, within toleranceM: Double) -> LayoutEdit? {
        let hall = layout.hall
        guard hall.count >= 3, let hit = closestEdge(to: point, in: hall, within: toleranceM) else {
            return nil
        }
        let start = hall[hit]
        let end = hall[(hit + 1) % hall.count]
        let span = end - start
        let length = simd_length(span)
        guard length > epsilon else { return nil }

        let direction = span / length
        let projected = min(max(simd_dot(point - start, direction), 0), length)
        let snapped = min(max((projected / snapCellM).rounded() * snapCellM, 0), length)
        guard snapped > epsilon, length - snapped > epsilon else { return nil }

        let splitPoint = start + direction * snapped
        guard !hall.contains(where: { simd_distance($0, splitPoint) <= epsilon }) else { return nil }

        var updatedHall = hall
        updatedHall.insert(splitPoint, at: hit + 1)
        let before = LayoutOutline(hall: hall, sizeM: layout.sizeM)
        let after = LayoutOutline(hall: updatedHall, sizeM: layout.sizeM)
        return .setOutline(before: before, after: after)
    }

    static func move(edge: Int, to point: SIMD2<Double>, in layout: Layout) -> HallEdgeMove? {
        let hall = layout.hall
        guard hall.count >= 3, hall.indices.contains(edge) else { return nil }
        let start = hall[edge]
        let end = hall[(edge + 1) % hall.count]
        let span = end - start
        guard simd_length(span) > epsilon else { return nil }
        let direction = simd_normalize(span)
        let normal = SIMD2<Double>(-direction.y, direction.x)

        let raw = simd_dot(point - midpoint(of: edge, in: hall), normal)
        let offset = (raw / snapCellM).rounded() * snapCellM
        guard abs(offset) > epsilon else { return nil }

        let shift = normal * offset
        let touched = [start, end, start + shift, end + shift]
        let previewHall = cleanedHall(displacedHall(hall, edge: edge, shift: shift), touched: touched)
        let doorPlacements = movedDoorPlacements(in: layout, edgeStart: start, edgeEnd: end, shift: shift)
        let edit = commitEdit(in: layout, previewHall: previewHall, doorPlacements: doorPlacements)
        return HallEdgeMove(edit: edit, hall: previewHall, doorPlacements: doorPlacements)
    }

    private static func closestEdge(
        to point: SIMD2<Double>,
        in hall: [SIMD2<Double>],
        within toleranceM: Double
    ) -> Int? {
        hall.indices
            .compactMap { index -> (edge: Int, distance: Double)? in
                let start = hall[index]
                let end = hall[(index + 1) % hall.count]
                guard simd_length(end - start) > epsilon else { return nil }
                let dist = distance(from: point, toSegment: start, end)
                return dist <= toleranceM ? (index, dist) : nil
            }
            .min { $0.distance < $1.distance }?
            .edge
    }

    private static func displacedHall(
        _ hall: [SIMD2<Double>],
        edge: Int,
        shift: SIMD2<Double>
    ) -> [SIMD2<Double>] {
        let startIndex = edge
        let endIndex = (edge + 1) % hall.count
        let keepStart = isSplitVertex(at: startIndex, in: hall)
        let keepEnd = isSplitVertex(at: endIndex, in: hall)
        let shiftedStart = hall[startIndex] + shift
        let shiftedEnd = hall[endIndex] + shift

        var result: [SIMD2<Double>] = []
        result.reserveCapacity(hall.count + 2)
        for index in hall.indices {
            if index == startIndex {
                if keepStart { result.append(hall[index]) }
                result.append(shiftedStart)
            } else if index == endIndex {
                result.append(shiftedEnd)
                if keepEnd { result.append(hall[index]) }
            } else {
                result.append(hall[index])
            }
        }
        return result
    }

    /// Only vertices this drag moved or kept can be dropped as collinear, so split points elsewhere survive.
    private static func cleanedHall(_ hall: [SIMD2<Double>], touched: [SIMD2<Double>]) -> [SIMD2<Double>] {
        var vertices = hall
        var changed = true
        while changed && vertices.count > 3 {
            changed = collapseZeroLengthEdges(in: &vertices)
            if dropCollinearVertices(in: &vertices, touched: touched) {
                changed = true
            }
        }
        return vertices
    }

    private static func collapseZeroLengthEdges(in vertices: inout [SIMD2<Double>]) -> Bool {
        var changed = false
        var index = 0
        while index < vertices.count && vertices.count > 3 {
            let nextIndex = (index + 1) % vertices.count
            if simd_distance(vertices[index], vertices[nextIndex]) <= epsilon {
                let removeIndex = nextIndex == 0 ? index : nextIndex
                vertices.remove(at: removeIndex)
                changed = true
            } else {
                index += 1
            }
        }
        return changed
    }

    private static func dropCollinearVertices(in vertices: inout [SIMD2<Double>], touched: [SIMD2<Double>]) -> Bool {
        var changed = false
        var index = 0
        while index < vertices.count && vertices.count > 3 {
            let prev = vertices[(index - 1 + vertices.count) % vertices.count]
            let curr = vertices[index]
            let next = vertices[(index + 1) % vertices.count]
            let isTouched = touched.contains { simd_distance($0, curr) <= epsilon }
            if isTouched && areCollinear(prev, curr, next) {
                vertices.remove(at: index)
                changed = true
            } else {
                index += 1
            }
        }
        return changed
    }

    private static func areCollinearSameDirection(
        _ first: SIMD2<Double>,
        _ middle: SIMD2<Double>,
        _ last: SIMD2<Double>
    ) -> Bool {
        let v1 = middle - first
        let v2 = last - middle
        let len1 = simd_length(v1)
        let len2 = simd_length(v2)
        guard len1 > epsilon, len2 > epsilon else { return false }
        let u1 = v1 / len1
        let u2 = v2 / len2
        return abs(u1.x * u2.y - u1.y * u2.x) <= epsilon && simd_dot(u1, u2) > 0
    }

    private static func areCollinear(
        _ first: SIMD2<Double>,
        _ middle: SIMD2<Double>,
        _ last: SIMD2<Double>
    ) -> Bool {
        let v1 = middle - first
        let v2 = last - middle
        let len1 = simd_length(v1)
        let len2 = simd_length(v2)
        guard len1 > epsilon, len2 > epsilon else { return true }
        let u1 = v1 / len1
        let u2 = v2 / len2
        return abs(u1.x * u2.y - u1.y * u2.x) <= epsilon
    }

    private static func movedDoorPlacements(
        in layout: Layout,
        edgeStart: SIMD2<Double>,
        edgeEnd: SIMD2<Double>,
        shift: SIMD2<Double>
    ) -> [UUID: Placement] {
        var placements: [UUID: Placement] = [:]
        for door in layout.objects where door.kind == .door
            && distance(from: door.placement.center, toSegment: edgeStart, edgeEnd) <= PerimeterWalls.doorReachM {
            var moved = door.placement
            moved.center += shift
            placements[door.id] = moved
        }
        return placements
    }

    private static func commitEdit(
        in layout: Layout,
        previewHall: [SIMD2<Double>],
        doorPlacements: [UUID: Placement]
    ) -> LayoutEdit {
        let minX = previewHall.map(\.x).min() ?? 0
        let minY = previewHall.map(\.y).min() ?? 0
        let originShift = SIMD2<Double>(max(0, -minX), max(0, -minY))
        if originShift.x > 1e-9 || originShift.y > 1e-9 {
            return shiftedCommitEdit(
                in: layout,
                previewHall: previewHall,
                doorPlacements: doorPlacements,
                originShift: originShift
            )
        }

        let sizeM = SIMD2<Double>(
            max(layout.sizeM.x, previewHall.map(\.x).max() ?? 0),
            max(layout.sizeM.y, previewHall.map(\.y).max() ?? 0)
        )
        let before = LayoutOutline(hall: layout.hall, sizeM: layout.sizeM)
        let after = LayoutOutline(hall: previewHall, sizeM: sizeM)
        var edits: [LayoutEdit] = [.setOutline(before: before, after: after)]
        for object in layout.objects {
            guard let movedPlacement = doorPlacements[object.id] else { continue }
            var moved = object
            moved.placement = movedPlacement
            edits.append(.replace(before: object, after: moved))
        }
        return .batch(edits)
    }

    private static func shiftedCommitEdit(
        in layout: Layout,
        previewHall: [SIMD2<Double>],
        doorPlacements: [UUID: Placement],
        originShift: SIMD2<Double>
    ) -> LayoutEdit {
        let committedHall = previewHall.map { $0 + originShift }
        let shiftedLobby = layout.lobby.map { $0 + originShift }
        let shiftedMarkers = layout.markers.map { marker -> LayoutMarker in
            var updated = marker
            updated.position += originShift
            return updated
        }
        let shiftedZones = layout.zones.map { zone -> LayoutZone in
            var updated = zone
            updated.minX += originShift.x
            updated.maxX += originShift.x
            updated.labelPosition += originShift
            return updated
        }

        var objectEdits: [LayoutEdit] = []
        var shiftedObjects: [LayoutObject] = []
        for object in layout.objects {
            var updated = object
            if let movedPlacement = doorPlacements[object.id] {
                updated.placement = movedPlacement
            }
            updated.placement.center += originShift
            shiftedObjects.append(updated)
            objectEdits.append(.replace(before: object, after: updated))
        }

        let sizeM = fittedSizeM(
            base: layout.sizeM,
            outline: LayoutOutline(
                hall: committedHall,
                sizeM: layout.sizeM,
                lobby: shiftedLobby,
                markers: shiftedMarkers,
                zones: shiftedZones
            ),
            objects: shiftedObjects
        )
        let before = LayoutOutline(layout: layout)
        let after = LayoutOutline(
            hall: committedHall,
            sizeM: sizeM,
            lobby: shiftedLobby,
            markers: shiftedMarkers,
            zones: shiftedZones
        )
        return .batch([.setOutline(before: before, after: after)] + objectEdits)
    }

    private static func fittedSizeM(
        base: SIMD2<Double>,
        outline: LayoutOutline,
        objects: [LayoutObject]
    ) -> SIMD2<Double> {
        let lobby = outline.lobby ?? []
        let markers = outline.markers ?? []
        let zones = outline.zones ?? []
        let objectBounds = objects.map { LayoutGeometry.bounds(of: $0.placement) }
        let maxX = [
            base.x,
            outline.hall.map(\.x).max() ?? 0,
            lobby.map(\.x).max() ?? 0,
            markers.map(\.position.x).max() ?? 0,
            zones.map(\.maxX).max() ?? 0,
            zones.map(\.labelPosition.x).max() ?? 0,
            objectBounds.map(\.maxX).max() ?? 0
        ].max() ?? base.x
        let maxY = [
            base.y,
            outline.hall.map(\.y).max() ?? 0,
            lobby.map(\.y).max() ?? 0,
            markers.map(\.position.y).max() ?? 0,
            zones.map(\.labelPosition.y).max() ?? 0,
            objectBounds.map(\.maxY).max() ?? 0
        ].max() ?? base.y
        return SIMD2<Double>(maxX, maxY)
    }

    private static func distance(
        from point: SIMD2<Double>,
        toSegment start: SIMD2<Double>,
        _ end: SIMD2<Double>
    ) -> Double {
        let span = end - start
        let lengthSq = simd_dot(span, span)
        guard lengthSq > 1e-12 else { return simd_distance(point, start) }
        let along = min(max(simd_dot(point - start, span) / lengthSq, 0), 1)
        return simd_distance(point, start + span * along)
    }
}

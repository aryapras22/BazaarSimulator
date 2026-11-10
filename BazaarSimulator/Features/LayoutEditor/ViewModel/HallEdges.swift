import Foundation
import simd

struct LayoutOutline: Equatable, Sendable {
    var hall: [SIMD2<Double>]
    var sizeM: SIMD2<Double>
}

struct HallEdgeMove: Sendable {
    let edit: LayoutEdit
    let hall: [SIMD2<Double>]
    let doorPlacements: [UUID: Placement]
}

enum HallEdges {
    static let snapCellM = 0.25

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

    /// Pushes both ends of an edge along its normal so the pointer stays on the handle, keeping the hall in the
    /// positive quadrant. Doors sitting on the edge travel with it.
    static func move(edge: Int, to point: SIMD2<Double>, in layout: Layout) -> HallEdgeMove? {
        let hall = layout.hall
        guard hall.count >= 3 else { return nil }
        let start = hall[edge]
        let end = hall[(edge + 1) % hall.count]
        let direction = simd_normalize(end - start)
        let normal = SIMD2<Double>(-direction.y, direction.x)

        let raw = simd_dot(point - midpoint(of: edge, in: hall), normal)
        let offset = clamped((raw / snapCellM).rounded() * snapCellM, normal: normal, ends: [start, end])
        guard abs(offset) > 1e-6 else { return nil }

        let shift = normal * offset
        var movedHall = hall
        movedHall[edge] = start + shift
        movedHall[(edge + 1) % hall.count] = end + shift

        let sizeM = SIMD2(
            max(layout.sizeM.x, movedHall.map(\.x).max() ?? 0),
            max(layout.sizeM.y, movedHall.map(\.y).max() ?? 0)
        )
        let before = LayoutOutline(hall: hall, sizeM: layout.sizeM)
        let after = LayoutOutline(hall: movedHall, sizeM: sizeM)

        var edits: [LayoutEdit] = [.setOutline(before: before, after: after)]
        var doorPlacements: [UUID: Placement] = [:]
        for door in layout.objects where door.kind == .door
            && distance(from: door.placement.center, toSegment: start, end) <= PerimeterWalls.doorReachM {
            var moved = door
            moved.placement.center += shift
            edits.append(.replace(before: door, after: moved))
            doorPlacements[door.id] = moved.placement
        }
        return HallEdgeMove(edit: .batch(edits), hall: movedHall, doorPlacements: doorPlacements)
    }

    private static func clamped(_ offset: Double, normal: SIMD2<Double>, ends: [SIMD2<Double>]) -> Double {
        var lower = -Double.infinity
        var upper = Double.infinity
        for end in ends {
            for axis in 0..<2 where abs(normal[axis]) > 1e-9 {
                let limit = -end[axis] / normal[axis]
                if normal[axis] > 0 { lower = max(lower, limit) } else { upper = min(upper, limit) }
            }
        }
        return min(max(offset, lower), upper)
    }

    private static func distance(
        from point: SIMD2<Double>,
        toSegment start: SIMD2<Double>,
        _ end: SIMD2<Double>
    ) -> Double {
        let span = end - start
        let along = min(max(simd_dot(point - start, span) / simd_dot(span, span), 0), 1)
        return simd_distance(point, start + span * along)
    }
}

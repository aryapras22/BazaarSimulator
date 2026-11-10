import Foundation
import simd

extension WallEditing {
    /// Adds a point wherever a drawn segment crosses the centreline of an existing wall, so both can be split there.
    static func pointsWithCrossings(_ points: [SIMD2<Double>], in layout: Layout) -> [SIMD2<Double>] {
        guard points.count >= 2 else { return points }
        let centrelines = layout.objects.filter { $0.kind == .wall }.map(centreline)
        var result = [points[0]]
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let crossings = centrelines
                .compactMap { crossing(of: (start, end), with: $0) }
                .sorted { $0.t < $1.t }
            result.append(contentsOf: crossings.map(\.point))
            result.append(end)
        }
        return result
    }

    private static func centreline(of wall: LayoutObject) -> (SIMD2<Double>, SIMD2<Double>) {
        let halfL = wall.placement.sizeM.x / 2.0
        return (
            LayoutGeometry.toWorld(local: SIMD2<Double>(-halfL, 0), in: wall.placement),
            LayoutGeometry.toWorld(local: SIMD2<Double>(halfL, 0), in: wall.placement)
        )
    }

    private static func crossing(
        of segment: (SIMD2<Double>, SIMD2<Double>),
        with wall: (SIMD2<Double>, SIMD2<Double>)
    ) -> (t: Double, point: SIMD2<Double>)? {
        let edge = 1e-3
        let direction = segment.1 - segment.0
        let wallDirection = wall.1 - wall.0
        let denominator = direction.x * wallDirection.y - direction.y * wallDirection.x
        guard abs(denominator) > 1e-9 else { return nil }
        let offset = wall.0 - segment.0
        let along = (offset.x * wallDirection.y - offset.y * wallDirection.x) / denominator
        let alongWall = (offset.x * direction.y - offset.y * direction.x) / denominator
        guard along > edge, along < 1 - edge, alongWall > edge, alongWall < 1 - edge else { return nil }
        return (along, segment.0 + direction * along)
    }
}

import Foundation
import simd

/// Tidies the walls read from a plan: drops stubs too short to be a wall and joins collinear walls that nearly touch
/// when no door sits in the gap between them.
enum WallCleanup {
    static let minLengthM = 1.0
    static let maxGapM = 1.0
    static let maxAngleRadians = 5.0 * .pi / 180

    static func apply(to objects: [LayoutObject]) -> [LayoutObject] {
        let doors = objects.filter { $0.kind == .door }
        var walls = objects.filter { $0.kind == .wall && $0.placement.sizeM.x >= minLengthM }
        var merged = true
        while merged {
            merged = false
            search: for first in walls.indices {
                for second in walls.indices where second > first {
                    if let joined = join(walls[first], walls[second], doors: doors) {
                        walls[first] = joined
                        walls.remove(at: second)
                        merged = true
                        break search
                    }
                }
            }
        }
        return objects.filter { $0.kind != .wall } + walls
    }

    private static func join(_ first: LayoutObject, _ second: LayoutObject, doors: [LayoutObject]) -> LayoutObject? {
        let direction = unit(first.placement)
        let other = unit(second.placement)
        let cross = abs(direction.x * other.y - direction.y * other.x)
        guard cross < sin(maxAngleRadians) else { return nil }

        let ends = endpoints(first.placement) + endpoints(second.placement)
        let thickness = max(first.placement.sizeM.y, second.placement.sizeM.y)
        let offset = abs(cross2(second.placement.center - first.placement.center, direction))
        guard offset <= thickness else { return nil }

        let gapEnds = closestEnds(endpoints(first.placement), endpoints(second.placement))
        let gap = simd_distance(gapEnds.0, gapEnds.1)
        guard gap <= maxGapM else { return nil }
        let strip = Placement(
            center: (gapEnds.0 + gapEnds.1) / 2,
            sizeM: SIMD2(gap, thickness * 2),
            rotationRadians: first.placement.rotationRadians
        )
        guard !doors.contains(where: { LayoutGeometry.intersects($0.placement, strip) }) else { return nil }

        let span = pairs(of: ends).max { simd_distance($0.0, $0.1) < simd_distance($1.0, $1.1) }
        guard let (start, end) = span else { return nil }
        var joined = first
        joined.placement = Placement(
            center: (start + end) / 2,
            sizeM: SIMD2(simd_distance(start, end), thickness),
            rotationRadians: first.placement.rotationRadians
        )
        return joined
    }

    private static func unit(_ placement: Placement) -> SIMD2<Double> {
        SIMD2(cos(placement.rotationRadians), sin(placement.rotationRadians))
    }

    private static func endpoints(_ placement: Placement) -> [SIMD2<Double>] {
        let half = unit(placement) * (placement.sizeM.x / 2)
        return [placement.center - half, placement.center + half]
    }

    private static func cross2(_ vector: SIMD2<Double>, _ direction: SIMD2<Double>) -> Double {
        vector.x * direction.y - vector.y * direction.x
    }

    private static func pairs(of points: [SIMD2<Double>]) -> [(SIMD2<Double>, SIMD2<Double>)] {
        points.indices.flatMap { low in
            points.indices.filter { $0 > low }.map { (points[low], points[$0]) }
        }
    }

    private static func closestEnds(
        _ first: [SIMD2<Double>],
        _ second: [SIMD2<Double>]
    ) -> (SIMD2<Double>, SIMD2<Double>) {
        let candidates = first.flatMap { start in second.map { (start, $0) } }
        return candidates.min { simd_distance($0.0, $0.1) < simd_distance($1.0, $1.1) } ?? (first[0], second[0])
    }
}

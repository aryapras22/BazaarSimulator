import Foundation
import simd

/// Tidies the walls read from a plan: drops stubs too short to be a wall and joins collinear walls that touch or nearly
/// touch when no door sits in the gap between them. The limits come from the six sample plans: real walls are at least
/// 1.9 m long, and gaps between collinear walls are either 0.55 m or less (broken lines) or 1.7 m or more (openings).
enum WallCleanup {
    static let minLengthM = 1.0
    static let maxGapM = 0.6
    static let maxAngleRadians = 5.0 * .pi / 180

    /// A wall as a line: centre, unit direction along its length, length and thickness. Extracted boxes are not
    /// rotated, so a vertical wall is a box taller than wide and its length is the larger side.
    private struct Line {
        var center: SIMD2<Double>
        var direction: SIMD2<Double>
        var length: Double
        var thickness: Double

        init(_ placement: Placement) {
            let angle = placement.rotationRadians + (placement.sizeM.y > placement.sizeM.x ? .pi / 2 : 0)
            center = placement.center
            direction = SIMD2(cos(angle), sin(angle))
            length = max(placement.sizeM.x, placement.sizeM.y)
            thickness = min(placement.sizeM.x, placement.sizeM.y)
        }

        init(center: SIMD2<Double>, direction: SIMD2<Double>, length: Double, thickness: Double) {
            self.center = center
            self.direction = direction
            self.length = length
            self.thickness = thickness
        }

        func along(_ point: SIMD2<Double>) -> Double {
            simd_dot(point - center, direction)
        }

        var placement: Placement {
            Placement(
                center: center,
                sizeM: SIMD2(length, thickness),
                rotationRadians: atan2(direction.y, direction.x)
            )
        }
    }

    static func apply(to objects: [LayoutObject]) -> [LayoutObject] {
        let doors = objects.filter { $0.kind == .door }
        var walls = objects.filter { $0.kind == .wall && max($0.placement.sizeM.x, $0.placement.sizeM.y) >= minLengthM }
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
        let lineA = Line(first.placement)
        let lineB = Line(second.placement)
        let cross = lineA.direction.x * lineB.direction.y - lineA.direction.y * lineB.direction.x
        guard abs(cross) < sin(maxAngleRadians) else { return nil }

        let thickness = max(lineA.thickness, lineB.thickness)
        let offset = (lineB.center - lineA.center)
        guard abs(offset.x * lineA.direction.y - offset.y * lineA.direction.x) <= thickness else { return nil }

        let spanA = (-lineA.length / 2, lineA.length / 2)
        let centerB = lineA.along(lineB.center)
        let spanB = (centerB - lineB.length / 2, centerB + lineB.length / 2)
        let gap = max(spanA.0, spanB.0) - min(spanA.1, spanB.1)
        guard gap <= maxGapM else { return nil }
        if gap > 0 {
            let strip = Placement(
                center: lineA.center + lineA.direction * ((min(spanA.1, spanB.1) + max(spanA.0, spanB.0)) / 2),
                sizeM: SIMD2(gap, thickness * 2),
                rotationRadians: atan2(lineA.direction.y, lineA.direction.x)
            )
            guard !doors.contains(where: { LayoutGeometry.intersects($0.placement, strip) }) else { return nil }
        }

        let low = min(spanA.0, spanB.0)
        let high = max(spanA.1, spanB.1)
        var joined = first
        joined.placement = Line(
            center: lineA.center + lineA.direction * ((low + high) / 2),
            direction: lineA.direction,
            length: high - low,
            thickness: thickness
        ).placement
        return joined
    }
}

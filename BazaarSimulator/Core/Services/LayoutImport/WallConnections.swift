import Foundation
import simd

/// Removes the noise the extractor leaves around walls and doors and joins what is left: window frame lines beside a
/// wall, thin tick marks, walls that stop short of a corner, doors too narrow to walk through, and doors that sit
/// beside a wall instead of in it. Runs after `WallCleanup` has joined collinear walls.
enum WallConnections {
    static let frameReachM = 1.5
    static let tickMaxLengthM = 3.0
    static let tickMaxThicknessM = 0.12
    static let isolationM = 1.0
    static let cornerReachM = 1.0
    static let minDoorWidthM = 0.7
    static let doorReachM = 0.5

    /// A wall as a segment between its two ends.
    private struct Segment {
        var wall: LayoutObject
        var start: SIMD2<Double>
        var end: SIMD2<Double>
        var thickness: Double

        init(_ wall: LayoutObject) {
            let placement = wall.placement
            let angle = placement.rotationRadians + (placement.sizeM.y > placement.sizeM.x ? .pi / 2 : 0)
            let offset = SIMD2(cos(angle), sin(angle)) * (max(placement.sizeM.x, placement.sizeM.y) / 2)
            self.wall = wall
            start = placement.center - offset
            end = placement.center + offset
            thickness = min(placement.sizeM.x, placement.sizeM.y)
        }

        var length: Double { simd_length(end - start) }
        var direction: SIMD2<Double> { (end - start) / max(length, 1e-9) }

        /// Distance along the wall from its start, and distance to its line, for a point.
        func locate(_ point: SIMD2<Double>) -> (along: Double, across: Double) {
            let offset = point - start
            let along = simd_dot(offset, direction)
            let across = abs(offset.x * direction.y - offset.y * direction.x)
            return (along, across)
        }

        func distance(to point: SIMD2<Double>) -> Double {
            let (along, across) = locate(point)
            if along < 0 { return simd_length(point - start) }
            if along > length { return simd_length(point - end) }
            return across
        }

        var placement: Placement {
            Placement(
                center: (start + end) / 2,
                sizeM: SIMD2(length, thickness),
                rotationRadians: atan2(end.y - start.y, end.x - start.x)
            )
        }
    }

    static func apply(to objects: [LayoutObject]) -> [LayoutObject] {
        var segments = objects.filter { $0.kind == .wall }.map { Segment($0) }
        segments = dropFrameLines(segments)
        segments = dropTicks(segments)
        segments = connectCorners(segments)
        let walls = segments.map { segment in
            var wall = segment.wall
            wall.placement = segment.placement
            return wall
        }
        return objects.filter { $0.kind != .wall && $0.kind != .door } + walls + seatedDoors(in: objects, on: segments)
    }

    private static func isParallel(_ first: Segment, _ second: Segment) -> Bool {
        let cross = first.direction.x * second.direction.y - first.direction.y * second.direction.x
        return abs(cross) < sin(5 * .pi / 180)
    }

    /// A thinner, shorter wall that runs along a longer one within reach is a window frame line, not a wall.
    private static func dropFrameLines(_ segments: [Segment]) -> [Segment] {
        segments.indices.filter { index in
            let line = segments[index]
            return !segments.indices.contains { other in
                let host = segments[other]
                guard other != index, isParallel(line, host), host.length > line.length,
                      line.thickness < host.thickness else { return false }
                let middle = host.locate((line.start + line.end) / 2)
                return middle.across <= frameReachM && middle.along >= 0 && middle.along <= host.length
            }
        }.map { segments[$0] }
    }

    /// A short, thin wall far from every other wall is a symbol mark, such as the bars around a door.
    private static func dropTicks(_ segments: [Segment]) -> [Segment] {
        segments.indices.filter { index in
            let tick = segments[index]
            guard tick.length <= tickMaxLengthM, tick.thickness < tickMaxThicknessM else { return true }
            return segments.indices.contains { other in
                other != index
                    && [tick.start, tick.end].contains { segments[other].distance(to: $0) <= isolationM }
            }
        }.map { segments[$0] }
    }

    /// An end that stops short of another wall's line is stretched to it, so the two walls meet.
    private static func connectCorners(_ segments: [Segment]) -> [Segment] {
        var result = segments
        for index in result.indices {
            for end in [true, false] {
                let point = end ? result[index].end : result[index].start
                let outward = end ? result[index].direction : -result[index].direction
                var nearest: (reach: Double, target: SIMD2<Double>)?
                for other in segments.indices where other != index && !isParallel(result[index], segments[other]) {
                    guard let hit = meeting(from: point, outward: outward, wall: segments[other]),
                          nearest == nil || hit.reach < nearest!.reach else { continue }
                    nearest = hit
                }
                guard let nearest, nearest.reach > 0 else { continue }
                if end { result[index].end = nearest.target } else { result[index].start = nearest.target }
            }
        }
        return result
    }

    /// Where the ray from an end meets a wall's line, when that is close and falls on or beside the wall.
    private static func meeting(
        from point: SIMD2<Double>, outward: SIMD2<Double>, wall: Segment
    ) -> (reach: Double, target: SIMD2<Double>)? {
        let normal = SIMD2(-wall.direction.y, wall.direction.x)
        let speed = simd_dot(outward, normal)
        guard abs(speed) > 0.5 else { return nil }
        let reach = simd_dot(wall.start - point, normal) / speed
        guard reach >= 0, reach <= cornerReachM else { return nil }
        let target = point + outward * reach
        let along = wall.locate(target).along
        guard along >= -cornerReachM, along <= wall.length + cornerReachM else { return nil }
        return (reach, target)
    }

    /// Drops doors too narrow to pass, and lays each remaining door on the wall beside it.
    private static func seatedDoors(in objects: [LayoutObject], on segments: [Segment]) -> [LayoutObject] {
        objects.filter { $0.kind == .door }.compactMap { door in
            let size = door.placement.sizeM
            let width = max(size.x, size.y)
            guard width >= minDoorWidthM else { return nil }
            let centre = door.placement.center
            let reach = width / 2
            let host = segments
                .filter { wall in
                    let spot = wall.locate(centre)
                    return spot.across <= doorReachM && spot.along >= -reach && spot.along <= wall.length + reach
                }
                .min { $0.locate(centre).across < $1.locate(centre).across }
            guard let host else { return door }
            let located = host.locate(centre)
            var seated = door
            seated.placement = Placement(
                center: host.start + host.direction * located.along,
                sizeM: SIMD2(width, host.thickness),
                rotationRadians: atan2(host.direction.y, host.direction.x)
            )
            return seated
        }
    }
}

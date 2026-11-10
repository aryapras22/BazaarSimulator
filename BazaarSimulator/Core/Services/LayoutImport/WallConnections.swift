import Foundation
import simd

/// Removes the noise the extractor leaves around walls and doors and joins what is left: window frame lines beside a
/// wall, thin tick marks, walls that stop short of a corner, walls and doors that connect to nothing, and doors too
/// narrow to walk through. Runs after `WallCleanup` has joined collinear walls.
enum WallConnections {
    static let frameReachM = 1.5
    static let tickMaxLengthM = 3.0
    static let tickMaxThicknessM = 0.12
    static let isolationM = 1.0
    static let cornerReachM = 2.0
    static let touchM = 0.3
    static let stackedReachM = 0.8
    static let minDoorWidthM = 0.7
    static let doorReachM = 2.0
    static let doorTouchM = 0.5
    static let doorGapReachM = 2.5
    static let doorLineReachM = 8.0

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
        let doors = objects.filter { $0.kind == .door && isWideEnough($0) }
        segments = mergeStacked(dropFrameLines(segments))
        segments = dropTicks(segments)
        segments = dropFloating(connectCorners(segments), doors: doors)
        let seated = seatedDoors(in: objects, on: segments)
        let walls = closeDoorGaps(segments, doors: seated).map { segment in
            var wall = segment.wall
            wall.placement = segment.placement
            return wall
        }
        return objects.filter { $0.kind != .wall && $0.kind != .door } + walls + seated
    }

    /// A door end with no wall against it gets the nearest wall on the same line stretched up to it.
    private static func closeDoorGaps(_ segments: [Segment], doors: [LayoutObject]) -> [Segment] {
        var result = segments
        for door in doors {
            let size = door.placement.sizeM
            let angle = door.placement.rotationRadians + (size.y > size.x ? .pi / 2 : 0)
            let direction = SIMD2(cos(angle), sin(angle))
            for point in ends(of: door) where !result.contains(where: { $0.distance(to: point) <= touchM }) {
                var best: (index: Int, atEnd: Bool)?
                var bestGap = doorGapReachM
                for index in result.indices {
                    let wall = result[index]
                    let cross = wall.direction.x * direction.y - wall.direction.y * direction.x
                    guard abs(cross) < sin(5 * .pi / 180), wall.locate(point).across <= touchM else { continue }
                    let atEnd = wall.locate(point).along > wall.length
                    let gap = simd_length(point - (atEnd ? wall.end : wall.start))
                    if gap <= bestGap {
                        bestGap = gap
                        best = (index, atEnd)
                    }
                }
                guard let best else { continue }
                if best.atEnd { result[best.index].end = point } else { result[best.index].start = point }
            }
        }
        return result
    }

    private static func ends(of door: LayoutObject) -> [SIMD2<Double>] {
        let size = door.placement.sizeM
        let angle = door.placement.rotationRadians + (size.y > size.x ? .pi / 2 : 0)
        let along = SIMD2(cos(angle), sin(angle)) * (max(size.x, size.y) / 2)
        return [door.placement.center - along, door.placement.center + along]
    }

    private static func isWideEnough(_ door: LayoutObject) -> Bool {
        max(door.placement.sizeM.x, door.placement.sizeM.y) >= minDoorWidthM
    }

    /// Two parallel walls drawn on top of each other are one thick wall, as the two edges of a double line.
    private static func mergeStacked(_ segments: [Segment]) -> [Segment] {
        var result = segments
        var merged = true
        while merged {
            merged = false
            search: for first in result.indices {
                for second in result.indices where second > first {
                    if let joined = stack(result[first], result[second]) {
                        result[first] = joined
                        result.remove(at: second)
                        merged = true
                        break search
                    }
                }
            }
        }
        return result
    }

    private static func stack(_ first: Segment, _ second: Segment) -> Segment? {
        guard isParallel(first, second) else { return nil }
        let normal = SIMD2(-first.direction.y, first.direction.x)
        let across = simd_dot((second.start + second.end) / 2 - first.start, normal)
        let startAlong = simd_dot(second.start - first.start, first.direction)
        let endAlong = simd_dot(second.end - first.start, first.direction)
        let overlap = min(first.length, max(startAlong, endAlong)) - max(0, min(startAlong, endAlong))
        guard abs(across) <= stackedReachM, overlap >= min(first.length, second.length) / 2 else { return nil }
        let low = min(0, startAlong, endAlong)
        let high = max(first.length, startAlong, endAlong)
        var joined = first
        joined.start = first.start + first.direction * low + normal * (across / 2)
        joined.end = first.start + first.direction * high + normal * (across / 2)
        joined.thickness = abs(across) + max(first.thickness, second.thickness)
        return joined
    }

    /// A wall that touches no other wall and no door is not part of the building. When none touches anything, the plan
    /// has no structure to judge against, so all stay.
    private static func dropFloating(_ segments: [Segment], doors: [LayoutObject]) -> [Segment] {
        let doorEnds = doors.flatMap(ends(of:))
        func touches(_ first: Segment, _ second: Segment) -> Bool {
            [second.start, second.end].contains { first.distance(to: $0) <= touchM }
        }
        let attached = segments.indices.filter { index in
            doorEnds.contains { segments[index].distance(to: $0) <= doorTouchM } || segments.indices.contains { other in
                other != index
                    && (touches(segments[index], segments[other]) || touches(segments[other], segments[index]))
            }
        }
        return attached.isEmpty ? segments : attached.map { segments[$0] }
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

    /// Drops doors too narrow to pass and doors with no wall within reach, and lays the rest on their wall.
    private static func seatedDoors(in objects: [LayoutObject], on segments: [Segment]) -> [LayoutObject] {
        objects.filter { $0.kind == .door }.compactMap { door in
            let size = door.placement.sizeM
            let width = max(size.x, size.y)
            guard width >= minDoorWidthM else { return nil }
            let centre = door.placement.center
            guard let host = host(of: centre, width: width, among: segments) else {
                return segments.isEmpty ? door : nil
            }
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

    /// The wall a door stands in: the closest wall line within reach, else a wall whose own line runs through the door
    /// from further off. The short wall pieces between doors in a row are often not read, so without the second rule
    /// only the door nearest the wall's end would stay.
    private static func host(of centre: SIMD2<Double>, width: Double, among segments: [Segment]) -> Segment? {
        func walls(across: Double, beyond: Double) -> [Segment] {
            segments.filter { wall in
                let spot = wall.locate(centre)
                return spot.across <= across && spot.along >= -beyond && spot.along <= wall.length + beyond
            }
        }
        let near = walls(across: doorReachM, beyond: width / 2 + doorReachM)
        let candidates = near.isEmpty ? walls(across: doorTouchM, beyond: doorLineReachM) : near
        return candidates.min { $0.locate(centre).across < $1.locate(centre).across }
    }
}

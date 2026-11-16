import Foundation
import simd

/// The floor of an imported plan. The walls of a plan also enclose the lobby and the rooms behind the hall, so the box
/// around every wall is larger than the hall. The hall is the smallest box that holds most of the booths and has
/// each side on a long wall line or on the edge of that outer box.
enum HallOutline {
    struct Floor {
        var hall: [SIMD2<Double>] = []
        var lobby: [SIMD2<Double>] = []
        /// The far corner of everything the walls enclose, which the layout has to be large enough to show.
        var extent = SIMD2<Double>.zero
    }

    /// Walls on one line bound the hall when together they cover this share of the plan. Shorter lines are the
    /// partitions of rooms and tenant spaces.
    private static let minimumCover = 0.5
    /// Some plans stand a few booths in the lobby, so the hall need not hold them all.
    private static let minimumBoothShare = 0.85
    private static let lineToleranceM = 0.5
    private static let doorReachM = 1.5
    private static let runAspect = 4.0

    static func floor(of objects: [LayoutObject]) -> Floor {
        let walls = objects.filter { $0.kind == .wall }.map { Box(LayoutGeometry.bounds(of: $0.placement)) }
        let basis = walls.isEmpty ? objects.map { Box(LayoutGeometry.bounds(of: $0.placement)) } : walls
        guard let first = basis.first else { return Floor() }
        let outer = basis.reduce(first) { Box(low: simd_min($0.low, $1.low), high: simd_max($0.high, $1.high)) }
        let booths = objects.filter { $0.kind == .booth }.map(\.placement.center)
        guard !booths.isEmpty else { return Floor(hall: outer.corners, extent: outer.high) }

        let hall = smallestBox(
            holding: booths,
            sidesX: [outer.low.x, outer.high.x] + wallLines(walls, along: 1, outer: outer),
            sidesY: [outer.low.y, outer.high.y] + wallLines(walls, along: 0, outer: outer)
        ) ?? outer
        let openDoors = objects.filter { $0.kind == .door && $0.doorFlow?.direction != .disabled }
        return Floor(
            hall: hall.corners,
            lobby: lobby(beyond: hall, within: outer, doors: openDoors),
            extent: outer.high
        )
    }

    /// Where the long wall lines running along one axis sit on the other axis.
    private static func wallLines(_ walls: [Box], along: Int, outer: Box) -> [Double] {
        let across = 1 - along
        let runs = walls
            .filter { $0.size[along] > $0.size[across] * runAspect }
            .sorted { $0.middle[across] < $1.middle[across] }
        var lines: [[Box]] = []
        for run in runs {
            if let start = lines.last?.first, run.middle[across] - start.middle[across] <= lineToleranceM {
                lines[lines.count - 1].append(run)
            } else {
                lines.append([run])
            }
        }
        return lines.compactMap { line in
            let cover = coveredLength(line.map { ($0.low[along], $0.high[along]) })
            guard cover >= outer.size[along] * minimumCover else { return nil }
            return line.map { $0.middle[across] }.reduce(0, +) / Double(line.count)
        }
    }

    /// The length the spans cover together, counting an overlap once.
    private static func coveredLength(_ spans: [(low: Double, high: Double)]) -> Double {
        var covered = 0.0
        var reached = -Double.infinity
        for span in spans.sorted(by: { $0.low < $1.low }) where span.high > reached {
            covered += span.high - max(span.low, reached)
            reached = span.high
        }
        return covered
    }

    private static func smallestBox(holding points: [SIMD2<Double>], sidesX: [Double], sidesY: [Double]) -> Box? {
        func pairs(_ sides: [Double]) -> [(Double, Double)] {
            sides.flatMap { low in sides.filter { $0 > low }.map { (low, $0) } }
        }
        let needed = Int((Double(points.count) * minimumBoothShare).rounded(.up))
        var best: Box?
        for (left, right) in pairs(sidesX) {
            for (top, bottom) in pairs(sidesY) {
                let box = Box(low: SIMD2(left, top), high: SIMD2(right, bottom))
                guard box.area < best?.area ?? .infinity, points.filter(box.contains).count >= needed else { continue }
                best = box
            }
        }
        return best
    }

    /// The strip between the hall and the outer box, on the side of the hall whose open doors are widest in total.
    /// Visitors reach the hall through it, so it has to be floor.
    private static func lobby(beyond hall: Box, within outer: Box, doors: [LayoutObject]) -> [SIMD2<Double>] {
        var widest = 0.0
        var strip: Box?
        for across in [0, 1] {
            let sides = [(hall.low[across], outer.low[across]), (hall.high[across], outer.high[across])]
            for (edge, limit) in sides where abs(edge - limit) > lineToleranceM {
                let width = doors
                    .filter { abs($0.placement.center[across] - edge) <= doorReachM }
                    .map { max($0.placement.sizeM.x, $0.placement.sizeM.y) }
                    .reduce(0, +)
                guard width > widest else { continue }
                widest = width
                var box = outer
                box.low[across] = min(edge, limit)
                box.high[across] = max(edge, limit)
                strip = box
            }
        }
        return strip?.corners ?? []
    }
}

private struct Box {
    var low: SIMD2<Double>
    var high: SIMD2<Double>

    var size: SIMD2<Double> { high - low }
    var middle: SIMD2<Double> { (low + high) / 2 }
    var area: Double { size.x * size.y }
    var corners: [SIMD2<Double>] { [low, SIMD2(high.x, low.y), high, SIMD2(low.x, high.y)] }

    init(low: SIMD2<Double>, high: SIMD2<Double>) {
        self.low = low
        self.high = high
    }

    init(_ bounds: BoundingBox) {
        low = SIMD2(bounds.minX, bounds.minY)
        high = SIMD2(bounds.maxX, bounds.maxY)
    }

    func contains(_ point: SIMD2<Double>) -> Bool {
        point.x >= low.x && point.x <= high.x && point.y >= low.y && point.y <= high.y
    }
}

import Foundation
import simd

enum OpenSideInference {
    static let probeDepthM: Double = 0.3

    /// Every side that is not blocked is open. A side is closed when a wall or other obstacle covers it.
    static func defaultSide(for booth: LayoutObject, in layout: Layout) -> OpenSides {
        infer(for: booth, in: layout)
    }

    static func infer(for booth: LayoutObject, in layout: Layout) -> OpenSides {
        var openSides: OpenSides = []
        for side in OpenSides.ordered where isSideOpen(side, of: booth, in: layout) {
            openSides.insert(side)
        }
        return openSides
    }

    static func isSideOpen(_ side: OpenSides, of booth: LayoutObject, in layout: Layout) -> Bool {
        isSideOpen(side, of: booth, in: layout, candidates: layout.objects)
    }

    static func isSideOpen(
        _ side: OpenSides,
        of booth: LayoutObject,
        in layout: Layout,
        candidates: [LayoutObject]
    ) -> Bool {
        let strip = LayoutGeometry.stripPlacement(
            for: side,
            of: booth.placement,
            depthM: probeDepthM
        )

        guard LayoutGeometry.isPlacementInsideWalkableFloor(strip, in: layout) else {
            return false
        }

        let isHorizontalSide = side == .top || side == .bottom
        let sideLength = isHorizontalSide ? booth.placement.sizeM.x : booth.placement.sizeM.y
        guard sideLength > 1e-6 else { return false }

        var intervals: [(start: Double, end: Double)] = []
        for candidate in candidates where candidate.id != booth.id {
            guard candidate.kind.blocksWalking else { continue }
            if LayoutGeometry.intersects(strip, candidate.placement),
               let interval = overlappingIntervalAlongSide(
                   side: side,
                   of: booth.placement,
                   with: candidate.placement
               ) {
                intervals.append(interval)
            }
        }

        let blockedSpan = mergedSpan(of: intervals)
        let requiredFreeLength = min(0.5, sideLength * 0.5)
        return blockedSpan < sideLength - requiredFreeLength
    }

    private static func overlappingIntervalAlongSide(
        side: OpenSides,
        of boothPlacement: Placement,
        with obstaclePlacement: Placement
    ) -> (start: Double, end: Double)? {
        let isHorizontalSide = side == .top || side == .bottom
        let halfLength = (isHorizontalSide ? boothPlacement.sizeM.x : boothPlacement.sizeM.y) / 2.0
        let localCorners = LayoutGeometry.corners(of: obstaclePlacement).map {
            LayoutGeometry.toLocal(point: $0, in: boothPlacement)
        }
        let coords = localCorners.map { isHorizontalSide ? $0.x : $0.y }
        guard let minCoord = coords.min(), let maxCoord = coords.max() else { return nil }
        let start = max(-halfLength, minCoord)
        let end = min(halfLength, maxCoord)
        guard end > start else { return nil }
        return (start, end)
    }

    private static func mergedSpan(of intervals: [(start: Double, end: Double)]) -> Double {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total = 0.0
        for next in sorted.dropFirst() {
            if next.start <= current.end {
                current.end = max(current.end, next.end)
            } else {
                total += current.end - current.start
                current = next
            }
        }
        total += current.end - current.start
        return total
    }
}

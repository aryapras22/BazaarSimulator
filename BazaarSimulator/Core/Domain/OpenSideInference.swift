import Foundation
import simd

enum OpenSideInference {
    static let probeDepthM: Double = 0.3

    static func infer(for booth: LayoutObject, in layout: Layout) -> OpenSides {
        var openSides: OpenSides = []
        for side in OpenSides.ordered where isSideOpen(side, of: booth, in: layout) {
            openSides.insert(side)
        }
        return openSides
    }

    static func isSideOpen(_ side: OpenSides, of booth: LayoutObject, in layout: Layout) -> Bool {
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

        var blockedSpan = 0.0
        for candidate in layout.objects where candidate.id != booth.id {
            guard candidate.kind.blocksWalking else { continue }
            if LayoutGeometry.intersects(strip, candidate.placement) {
                blockedSpan += overlappingSpanAlongSide(
                    side: side,
                    of: booth.placement,
                    with: candidate.placement
                )
            }
        }

        return blockedSpan < sideLength - 0.5
    }

    private static func overlappingSpanAlongSide(
        side: OpenSides,
        of boothPlacement: Placement,
        with obstaclePlacement: Placement
    ) -> Double {
        let isHorizontalSide = side == .top || side == .bottom
        let halfLength = (isHorizontalSide ? boothPlacement.sizeM.x : boothPlacement.sizeM.y) / 2.0
        let localCorners = LayoutGeometry.corners(of: obstaclePlacement).map {
            LayoutGeometry.toLocal(point: $0, in: boothPlacement)
        }
        let coords = localCorners.map { isHorizontalSide ? $0.x : $0.y }
        guard let minCoord = coords.min(), let maxCoord = coords.max() else { return 0 }
        let start = max(-halfLength, minCoord)
        let end = min(halfLength, maxCoord)
        return max(0, end - start)
    }
}

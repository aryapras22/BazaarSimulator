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

        for candidate in layout.objects where candidate.id != booth.id {
            guard candidate.kind.blocksWalking else { continue }
            if LayoutGeometry.intersects(strip, candidate.placement) {
                return false
            }
        }

        return true
    }
}

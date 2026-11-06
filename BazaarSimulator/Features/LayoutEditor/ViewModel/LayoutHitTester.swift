import Foundation
import simd

enum LayoutHitTester {
    static let doorToleranceM: Double = 0.3

    static func object(
        at world: SIMD2<Double>,
        in layout: Layout,
        layer: EditorLayer
    ) -> LayoutObject.ID? {
        let ordered = drawOrderedObjects(in: layout)
        for candidate in ordered.reversed() {
            guard candidate.kind.layer == layer && candidate.kind.isSelectable else { continue }
            if hits(candidate, at: world) {
                return candidate.id
            }
        }
        return nil
    }

    static func lockedObject(
        at world: SIMD2<Double>,
        in layout: Layout,
        currentLayer: EditorLayer
    ) -> LayoutObject? {
        let ordered = drawOrderedObjects(in: layout)
        for candidate in ordered.reversed() {
            guard candidate.kind.layer != currentLayer && candidate.kind.isSelectable else { continue }
            if hits(candidate, at: world) {
                return candidate
            }
        }
        return nil
    }

    static func drawOrderedObjects(in layout: Layout) -> [LayoutObject] {
        layout.objects.sorted { drawRank(for: $0.kind) < drawRank(for: $1.kind) }
    }

    private static func hits(_ object: LayoutObject, at world: SIMD2<Double>) -> Bool {
        if let catalogID = object.catalogID,
           let item = ObjectCatalog.item(catalogID),
           item.footprint == .circle {
            return LayoutGeometry.containsCircle(
                center: object.placement.center,
                diameter: object.placement.sizeM.x,
                point: world
            )
        }

        switch object.kind {
        case .door:
            return LayoutGeometry.contains(
                object.placement,
                point: world,
                tolerance: doorToleranceM
            )
        default:
            return LayoutGeometry.contains(object.placement, point: world)
        }
    }

    private static func drawRank(for kind: LayoutObjectKind) -> Int {
        switch kind {
        case .floor: return -1
        case .closedArea: return 0
        case .wall, .block: return 1
        case .booth: return 2
        case .door: return 3
        }
    }
}

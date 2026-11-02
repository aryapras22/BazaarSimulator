import Foundation
import simd

enum LayoutHitTester {
    static let doorToleranceM: Double = 0.3

    static func object(
        at world: SIMD2<Double>,
        in layout: Layout,
        tab: EditorTab
    ) -> LayoutObject.ID? {
        let ordered = drawOrderedObjects(in: layout)
        for candidate in ordered.reversed() {
            guard isSelectable(candidate, in: tab) else { continue }
            if hits(candidate, at: world) {
                return candidate.id
            }
        }
        return nil
    }

    static func drawOrderedObjects(in layout: Layout) -> [LayoutObject] {
        layout.objects.sorted { drawRank(for: $0.kind) < drawRank(for: $1.kind) }
    }

    private static func isSelectable(_ object: LayoutObject, in tab: EditorTab) -> Bool {
        object.kind.tab == tab.objectTab && object.kind.isSelectable
    }

    private static func hits(_ object: LayoutObject, at world: SIMD2<Double>) -> Bool {
        switch object.kind {
        case .pillar:
            return LayoutGeometry.containsCircle(
                center: object.placement.center,
                diameter: object.placement.sizeM.x,
                point: world
            )
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
        case .closedArea: return 0
        case .audienceArea: return 1
        case .stage: return 2
        case .table: return 3
        case .fixture: return 4
        case .wall, .rail, .block, .pillar: return 5
        case .booth: return 6
        case .door: return 7
        }
    }
}

import CoreGraphics
import Foundation
import simd

enum SelectGesture {
    static let dragThresholdPt: Double = 4.0

    static func isPastThreshold(_ delta: SIMD2<Double>, threshold: Double = dragThresholdPt) -> Bool {
        simd_length(delta) > threshold
    }

    static func isPastThreshold(_ delta: CGPoint, threshold: CGFloat = CGFloat(dragThresholdPt)) -> Bool {
        hypot(delta.x, delta.y) > threshold
    }

    static func isPastThreshold(_ delta: CGSize, threshold: CGFloat = CGFloat(dragThresholdPt)) -> Bool {
        hypot(delta.width, delta.height) > threshold
    }

    static func lockAxis(_ delta: SIMD2<Double>) -> SIMD2<Double> {
        if abs(delta.x) >= abs(delta.y) {
            return SIMD2<Double>(delta.x, 0)
        } else {
            return SIMD2<Double>(0, delta.y)
        }
    }

    static func touchedObjects(in rect: BoundingBox, layout: Layout, layer: EditorLayer) -> Set<UUID> {
        let norm = BoundingBox(
            minX: min(rect.minX, rect.maxX),
            maxX: max(rect.minX, rect.maxX),
            minY: min(rect.minY, rect.maxY),
            maxY: max(rect.minY, rect.maxY)
        )
        var result = Set<UUID>()
        for object in layout.objects where object.kind.layer == layer && object.kind.isSelectable {
            let bounds = LayoutGeometry.bounds(of: object.placement)
            let intersects = norm.minX <= bounds.maxX
                && norm.maxX >= bounds.minX
                && norm.minY <= bounds.maxY
                && norm.maxY >= bounds.minY
            if intersects {
                result.insert(object.id)
            }
        }
        return result
    }

    static func touchedObjects(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        layout: Layout,
        layer: EditorLayer
    ) -> Set<UUID> {
        let box = BoundingBox(
            minX: min(start.x, end.x),
            maxX: max(start.x, end.x),
            minY: min(start.y, end.y),
            maxY: max(start.y, end.y)
        )
        return touchedObjects(in: box, layout: layout, layer: layer)
    }

    static func touchedBooths(in rect: BoundingBox, layout: Layout) -> Set<UUID> {
        let norm = BoundingBox(
            minX: min(rect.minX, rect.maxX),
            maxX: max(rect.minX, rect.maxX),
            minY: min(rect.minY, rect.maxY),
            maxY: max(rect.minY, rect.maxY)
        )
        var result = Set<UUID>()
        for object in layout.objects where object.kind == .booth {
            let bounds = LayoutGeometry.bounds(of: object.placement)
            let intersects = norm.minX <= bounds.maxX
                && norm.maxX >= bounds.minX
                && norm.minY <= bounds.maxY
                && norm.maxY >= bounds.minY
            if intersects {
                result.insert(object.id)
            }
        }
        return result
    }

    static func touchedBooths(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        layout: Layout
    ) -> Set<UUID> {
        let box = BoundingBox(
            minX: min(start.x, end.x),
            maxX: max(start.x, end.x),
            minY: min(start.y, end.y),
            maxY: max(start.y, end.y)
        )
        return touchedBooths(in: box, layout: layout)
    }
}

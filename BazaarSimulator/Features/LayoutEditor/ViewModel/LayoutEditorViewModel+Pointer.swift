import Foundation
import simd

extension LayoutEditorViewModel {
    var selectionBounds: BoundingBox? {
        let boxes = (selectedObject.map { [$0] } ?? selectedGroupMembers)
            .map { LayoutGeometry.bounds(of: $0.placement) }
        guard let first = boxes.first else { return nil }
        return boxes.dropFirst().reduce(first) { union, box in
            BoundingBox(
                minX: min(union.minX, box.minX),
                maxX: max(union.maxX, box.maxX),
                minY: min(union.minY, box.minY),
                maxY: max(union.maxY, box.maxY)
            )
        }
    }

    func pointerDescription(at world: SIMD2<Double>) -> String {
        guard let layout = activeLayout else { return "Outside" }
        guard let hitID = LayoutHitTester.object(at: world, in: layout, layer: activeLayer),
              let object = layout.objects.first(where: { $0.id == hitID }) else {
            let isOnFloor = LayoutGeometry.polygonContains(layout.hall, point: world)
                || LayoutGeometry.polygonContains(layout.lobby, point: world)
            return isOnFloor ? "Floor" : "Outside"
        }
        return description(of: object, in: layout)
    }

    private func description(of object: LayoutObject, in layout: Layout) -> String {
        let size = object.placement.sizeM
        let dimensions = "\(DimensionInput.text(for: size.x)) × \(DimensionInput.text(for: size.y)) m"
        switch object.kind {
        case .booth:
            let category = legend.entries.first { $0.id == object.categoryID }?.name ?? "Unassigned"
            return "Booth \(BoothLabelFormatter.display(object.label)) · \(category) · \(dimensions)"
        case .door:
            let direction = (object.doorFlow?.direction ?? .both).displayName
            let title = DoorLabelFormatter.displayTitle(for: object, in: layout)
            return "\(title) · \(direction) · \(DimensionInput.text(for: size.x)) m"
        default:
            return "\(object.kind.displayName) · \(dimensions)"
        }
    }
}

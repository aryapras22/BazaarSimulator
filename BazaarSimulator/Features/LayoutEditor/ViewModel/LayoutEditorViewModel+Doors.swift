import Foundation
import simd

extension LayoutEditorViewModel {
    func updateDoorPlacementPreview(at world: SIMD2<Double>, itemID: String) {
        guard let layout = activeLayout else {
            placementPreview = nil
            return
        }
        let item = ObjectCatalog.item(itemID)
        let width = item?.sizeM.x ?? 1.2
        if let host = DoorHosting.nearestHost(to: world, in: layout),
           let placement = DoorHosting.placement(width: width, on: host, near: world) {
            placementPreview = PlacementCandidate(placement: placement, isValid: true, note: nil)
        } else {
            let placement = Placement(
                center: world,
                sizeM: SIMD2<Double>(width, DoorHosting.defaultThicknessM + 0.1),
                rotationRadians: 0
            )
            placementPreview = PlacementCandidate(
                placement: placement,
                isValid: false,
                note: "Must be placed on a wall or edge"
            )
        }
    }

    func commitDoorPlacement(keepTool: Bool, itemID: String) {
        guard let candidate = placementPreview,
              candidate.isValid,
              let layout = activeLayout,
              let host = DoorHosting.nearestHost(to: candidate.placement.center, in: layout) else {
            return
        }

        let item = ObjectCatalog.item(itemID)
        let height = item?.heightM ?? 2.1
        let label = nextLabel(for: .door, in: layout)
        let door = LayoutObject(
            id: UUID(),
            kind: .door,
            label: label,
            placement: candidate.placement,
            doorFlow: DoorFlow(direction: .both, connection: host.connection),
            catalogID: itemID,
            heightM: height
        )

        withSingleRefresh {
            commitEdit(.insert(door, index: layout.objects.count))
            applySelection(door.id)
        }

        if !keepTool {
            selectTool(.select)
        } else {
            updateDoorPlacementPreview(at: candidate.placement.center, itemID: itemID)
        }
    }

    func constrainDragDelta(id: UUID, delta: SIMD2<Double>) -> SIMD2<Double> {
        guard let layout = activeLayout,
              let object = layout.objects.first(where: { $0.id == id }),
              object.kind == .door,
              let host = DoorHosting.nearestHost(to: object.placement.center, in: layout, reach: 0.3),
              let placement = DoorHosting.placement(
                  width: object.placement.sizeM.x,
                  on: host,
                  near: object.placement.center + delta
              ) else {
            return delta
        }
        return placement.center - object.placement.center
    }
}

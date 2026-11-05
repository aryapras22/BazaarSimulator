import CoreGraphics
import Foundation
import simd

@MainActor
final class DoorTool: EditorToolHandling {
    let itemID: String
    var tool: EditorTool { .placeDoor(itemID: itemID) }

    private(set) var candidate: PlacementCandidate?
    private var pressViewPoint: CGPoint = .zero

    init(itemID: String) {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        pressViewPoint = event.viewPoint
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        let item = ObjectCatalog.item(itemID)
        let width = item?.sizeM.x ?? 1.2
        let resolvedCandidate: PlacementCandidate
        if let host = DoorHosting.nearestHost(to: event.worldPoint, in: context.layout),
           let placement = DoorHosting.placement(width: width, on: host, near: event.worldPoint) {
            resolvedCandidate = PlacementCandidate(placement: placement, isValid: true, note: nil)
        } else {
            let placement = Placement(
                center: event.worldPoint,
                sizeM: SIMD2<Double>(width, DoorHosting.defaultThicknessM + 0.1),
                rotationRadians: 0
            )
            resolvedCandidate = PlacementCandidate(
                placement: placement,
                isValid: false,
                note: "Must be placed on a wall or edge"
            )
        }
        self.candidate = resolvedCandidate
        context.setPreview(CanvasDragState(
            placementCandidate: resolvedCandidate,
            placingSource: .catalog(itemID)
        ))
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        guard !SelectGesture.isPastThreshold(translation) || pressViewPoint == .zero else { return }

        if candidate == nil {
            handleMove(event, context: context)
        }
        guard let candidate, candidate.isValid,
              let host = DoorHosting.nearestHost(to: candidate.placement.center, in: context.layout) else {
            return
        }

        let item = ObjectCatalog.item(itemID)
        let height = item?.heightM ?? 2.1
        let label = LayoutObjectNaming.nextLabel(for: .door, in: context.layout)
        let door = LayoutObject(
            id: UUID(),
            kind: .door,
            label: label,
            placement: candidate.placement,
            doorFlow: DoorFlow(
                direction: .both,
                connection: DoorHosting.connection(for: candidate.placement.center, on: host, in: context.layout)
            ),
            catalogID: itemID,
            heightM: height
        )
        context.applyEdit(.insert(door, index: context.layout.objects.count))
        context.selectObject(door.id)
        self.candidate = nil
        context.clearPreview()
        context.switchTool(.select)
    }

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {}

    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        switch key {
        case .escape:
            cancel(context: context)
            return true
        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        candidate = nil
        context.clearPreview()
        context.switchTool(.select)
    }
}

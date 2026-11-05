import Foundation
import simd

@MainActor
final class FloorTool: EditorToolHandling {
    let itemID: String
    var tool: EditorTool { .floor(itemID: itemID) }

    private(set) var startWorld: SIMD2<Double>?
    private(set) var currentWorld: SIMD2<Double>?

    init(itemID: String = "floor") {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        startWorld = snapResult.point
        currentWorld = snapResult.point
        context.setPreview(CanvasDragState(
            drawingStart: startWorld,
            drawingCurrent: currentWorld,
            drawingKind: .floor,
            isOptionDown: isFree,
            guides: snapResult.guides
        ))
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        currentWorld = snapResult.point
        guard startWorld != nil else {
            context.setPreview(CanvasDragState(guides: snapResult.guides))
            return
        }
        context.setPreview(CanvasDragState(
            drawingStart: startWorld,
            drawingCurrent: currentWorld,
            drawingKind: .floor,
            isOptionDown: isFree,
            guides: snapResult.guides
        ))
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        defer {
            startWorld = nil
            currentWorld = nil
            context.clearPreview()
            context.switchTool(.select)
        }
        guard let start = startWorld, let current = currentWorld else { return }
        let isOptionDown = event.modifiers.contains(.option)
        if let placement = BlockedAreaDrawing.placement(from: start, to: current, snapped: !isOptionDown) {
            let floorObject = LayoutObject(
                kind: .floor,
                label: LayoutObjectNaming.nextLabel(for: .floor, in: context.layout),
                placement: placement,
                catalogID: itemID
            )
            context.applyEdit(.insert(floorObject, index: context.layout.objects.count))
            context.selectObject(floorObject.id)
        }
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
        startWorld = nil
        currentWorld = nil
        context.clearPreview()
        context.switchTool(.select)
    }
}

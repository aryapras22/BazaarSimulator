import Foundation
import simd

@MainActor
final class BlockedAreaTool: EditorToolHandling {
    let tool: EditorTool = .blockedArea

    private(set) var startWorld: SIMD2<Double>?
    private(set) var currentWorld: SIMD2<Double>?

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        startWorld = event.worldPoint
        currentWorld = event.worldPoint
        context.setPreview(CanvasDragState(
            drawingStart: startWorld,
            drawingCurrent: currentWorld,
            isOptionDown: event.modifiers.contains(.option)
        ))
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        guard startWorld != nil else { return }
        currentWorld = event.worldPoint
        context.setPreview(CanvasDragState(
            drawingStart: startWorld,
            drawingCurrent: currentWorld,
            isOptionDown: event.modifiers.contains(.option)
        ))
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        guard let start = startWorld, let current = currentWorld else { return }
        let isOptionDown = event.modifiers.contains(.option)
        if let placement = BlockedAreaDrawing.placement(from: start, to: current, snapped: !isOptionDown) {
            let area = LayoutObject(
                kind: .closedArea,
                label: LayoutObjectNaming.nextLabel(for: .closedArea, in: context.layout),
                placement: placement
            )
            context.applyEdit(.insert(area, index: context.layout.objects.count))
            context.selectObject(area.id)
        }
        startWorld = nil
        currentWorld = nil
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
        startWorld = nil
        currentWorld = nil
        context.clearPreview()
        context.switchTool(.select)
    }
}

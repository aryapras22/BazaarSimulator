import CoreGraphics
import Foundation

extension SelectTool {
    func updateHallDrag(edge: Int, event: CanvasPointerEvent, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        guard SelectGesture.isPastThreshold(translation) else { return }
        guard let move = HallEdges.move(edge: edge, to: event.worldPoint, in: context.layout) else {
            context.clearPreview()
            return
        }
        context.setPreview(CanvasDragState(
            pointerLocation: event.viewPoint,
            previewHall: move.hall,
            previewPlacements: move.doorPlacements
        ))
    }

    func finishHallDrag(edge: Int, event: CanvasPointerEvent, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        if SelectGesture.isPastThreshold(translation),
           let move = HallEdges.move(edge: edge, to: event.worldPoint, in: context.layout) {
            context.applyEdit(move.edit)
        }
        resetGesture()
        context.clearPreview()
    }
}

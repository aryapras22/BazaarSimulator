import Foundation
import simd

extension LayoutEditorViewModel: ToolContext {
    var layout: Layout {
        activeLayout ?? Layout(name: "", sizeM: SIMD2<Double>(20, 20))
    }

    var currentToolHandler: any EditorToolHandling {
        if let handler = activeToolHandler, handler.tool == tool {
            return handler
        }
        let newHandler = makeToolHandler(for: tool)
        activeToolHandler = newHandler
        return newHandler
    }

    func makeToolHandler(for tool: EditorTool) -> any EditorToolHandling {
        switch tool {
        case .select:
            return SelectTool()
        case .blockedArea:
            return BlockedAreaTool()
        case .place(let source):
            return PlaceTool(source: source, rotationDegrees: placementRotationDegrees)
        case .drawWall(let itemID):
            return WallTool(itemID: itemID)
        case .placeDoor(let itemID):
            return DoorTool(itemID: itemID)
        }
    }

    func setPreview(_ preview: CanvasDragState) {
        dragState = preview
    }

    func clearPreview() {
        dragState = CanvasDragState()
    }

    func applyEdit(_ edit: LayoutEdit) {
        commitEdit(edit)
    }

    func toggleSelection(_ id: UUID) {
        toggleBoothInSelection(id)
    }

    func switchTool(_ tool: EditorTool) {
        selectTool(tool)
    }

    func handlePointerPress(_ event: CanvasPointerEvent) {
        currentToolHandler.handlePress(event, context: self)
    }

    func handlePointerMove(_ event: CanvasPointerEvent) {
        currentToolHandler.handleMove(event, context: self)
    }

    func handlePointerRelease(_ event: CanvasPointerEvent) {
        currentToolHandler.handleRelease(event, context: self)
    }

    func handlePointerDoubleClick(_ event: CanvasPointerEvent) {
        currentToolHandler.handleDoubleClick(event, context: self)
    }

    @discardableResult
    func handleCanvasKey(_ key: CanvasKey) -> Bool {
        currentToolHandler.handleKey(key, context: self)
    }

    func cancelActiveTool() {
        currentToolHandler.cancel(context: self)
    }
}

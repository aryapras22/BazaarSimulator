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

    func applyEdit(_ edit: LayoutEdit, coalesceKey: String?) {
        commitEdit(edit, coalesceKey: coalesceKey)
    }

    func toggleSelection(_ id: UUID) {
        toggleBoothInSelection(id)
    }

    func switchTool(_ tool: EditorTool) {
        selectTool(tool)
    }

    func showTransientHint(_ message: String) {
        transientHintTask?.cancel()
        transientHint = message
        transientHintTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.transientHint = nil
        }
    }

    func handlePointerPress(_ event: CanvasPointerEvent) {
        sealHistory()
        currentToolHandler.handlePress(event, context: self)
    }

    func handlePointerMove(_ event: CanvasPointerEvent) {
        currentToolHandler.handleMove(event, context: self)
    }

    func handlePointerRelease(_ event: CanvasPointerEvent) {
        currentToolHandler.handleRelease(event, context: self)
        sealHistory()
    }

    func handlePointerDoubleClick(_ event: CanvasPointerEvent) {
        currentToolHandler.handleDoubleClick(event, context: self)
        sealHistory()
    }

    @discardableResult
    func handleCanvasKey(_ key: CanvasKey) -> Bool {
        currentToolHandler.handleKey(key, context: self)
    }

    func cancelActiveTool() {
        currentToolHandler.cancel(context: self)
        sealHistory()
    }

    func executeSwitchLayout(_ layoutID: UUID) {
        withSingleRefresh {
            session.setActiveLayoutID(layoutID, for: projectID)
            hasFittedTransform = false
            applySelection(nil)
        }
    }

    func executeHistoryAction(isUndo: Bool) {
        let edit = isUndo ? currentHistory.undo() : currentHistory.redo()
        if let edit {
            applyHistoryEdit(edit)
        }
    }
}

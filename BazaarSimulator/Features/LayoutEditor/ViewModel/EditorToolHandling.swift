import Foundation
import simd

enum CanvasKey: Sendable, Equatable, Hashable {
    case returnKey
    case escape
    case delete
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case character(Character)
}

@MainActor
protocol ToolContext: AnyObject {
    var layout: Layout { get }
    var selectionID: UUID? { get }
    var groupMemberIDs: Set<UUID> { get }
    var activeLayer: EditorLayer { get }
    func setPreview(_ preview: CanvasDragState)
    func clearPreview()
    func applyEdit(_ edit: LayoutEdit)
    func applyEdit(_ edit: LayoutEdit, coalesceKey: String?)
    func sealHistory()
    func selectObject(_ id: UUID?)
    func selectBooths(_ ids: Set<UUID>, additive: Bool)
    func toggleSelection(_ id: UUID)
    func switchTool(_ tool: EditorTool)
    func selectGroup(containing id: UUID, bySize: Bool)
    func nudgeSelected(by delta: SIMD2<Double>)
    func showTransientHint(_ message: String)
}

extension ToolContext {
    var activeLayer: EditorLayer { .structure }
    func applyEdit(_ edit: LayoutEdit, coalesceKey: String?) {
        applyEdit(edit)
    }
    func sealHistory() {}
    func switchTool(_ tool: EditorTool) {}
    func selectGroup(containing id: UUID, bySize: Bool) {}
    func nudgeSelected(by delta: SIMD2<Double>) {}
    func showTransientHint(_ message: String) {}
}

@MainActor
protocol EditorToolHandling: AnyObject {
    var tool: EditorTool { get }
    func handlePress(_ event: CanvasPointerEvent, context: ToolContext)
    func handleMove(_ event: CanvasPointerEvent, context: ToolContext)
    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext)
    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext)
    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool
    func cancel(context: ToolContext)
}

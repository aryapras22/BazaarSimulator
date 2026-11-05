import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
private final class FloorToolTestContext: ToolContext {
    var layout: Layout
    var selectionID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var preview: CanvasDragState?
    var appliedEdits: [LayoutEdit] = []
    var switchedTools: [EditorTool] = []
    var activeLayer: EditorLayer = .structure

    init(layout: Layout) {
        self.layout = layout
    }

    func setPreview(_ preview: CanvasDragState) {
        self.preview = preview
    }

    func clearPreview() {
        self.preview = nil
    }

    func applyEdit(_ edit: LayoutEdit) {
        appliedEdits.append(edit)
        layout = LayoutEditing.apply(edit, to: layout)
    }

    func applyEdit(_ edit: LayoutEdit, coalesceKey: String?) {
        applyEdit(edit)
    }

    func selectObject(_ id: UUID?) {
        selectionID = id
    }

    func selectBooths(_ ids: Set<UUID>, additive: Bool) {}
    func toggleSelection(_ id: UUID) {}
    func switchTool(_ tool: EditorTool) {
        switchedTools.append(tool)
    }
    func selectGroup(id: UUID, bySize: Bool) {}
    func showTransientHint(_ message: String) {}
    func nudgeSelection(by deltaM: SIMD2<Double>) {}
}

@Suite("Floor Tool Tests")
@MainActor
struct FloorToolTests {
    private func makeLayout() -> Layout {
        Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(20, 20),
            hall: [
                SIMD2<Double>(0, 0),
                SIMD2<Double>(20, 0),
                SIMD2<Double>(20, 20),
                SIMD2<Double>(0, 20)
            ],
            lobby: [],
            objects: [],
            markers: []
        )
    }

    @Test("Dragging floor tool inserts floor object and switches to select")
    func dragCreatesFloorObject() {
        let tool = FloorTool(itemID: "floor")
        let context = FloorToolTestContext(layout: makeLayout())

        tool.handlePress(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2), pointsPerMetre: 10),
            context: context
        )
        tool.handleMove(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 8), pointsPerMetre: 10),
            context: context
        )
        tool.handleRelease(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 8), pointsPerMetre: 10),
            context: context
        )

        #expect(context.appliedEdits.count == 1)
        #expect(context.layout.objects.count == 1)
        guard let created = context.layout.objects.first else { return }
        #expect(created.kind == .floor)
        #expect(created.catalogID == "floor")
        #expect(abs(created.placement.sizeM.x - 4.0) < 0.01)
        #expect(abs(created.placement.sizeM.y - 6.0) < 0.01)
        #expect(context.selectionID == created.id)
        #expect(context.switchedTools.last == .select)
    }

    @Test("Dragging floor below minimum dimension is ignored")
    func dragBelowMinimumIsIgnored() {
        let tool = FloorTool(itemID: "floor")
        let context = FloorToolTestContext(layout: makeLayout())

        tool.handlePress(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2), pointsPerMetre: 10),
            context: context
        )
        tool.handleRelease(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(2.1, 2.1), pointsPerMetre: 10),
            context: context
        )

        #expect(context.appliedEdits.isEmpty)
        #expect(context.layout.objects.isEmpty)
        #expect(context.switchedTools.last == .select)
    }

    @Test("Escape key cancels floor tool")
    func escapeCancelsTool() {
        let tool = FloorTool(itemID: "floor")
        let context = FloorToolTestContext(layout: makeLayout())

        tool.handlePress(
            CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2), pointsPerMetre: 10),
            context: context
        )
        #expect(context.preview != nil)

        let handled = tool.handleKey(.escape, context: context)
        #expect(handled)
        #expect(context.preview == nil)
        #expect(context.switchedTools.last == .select)
    }
}

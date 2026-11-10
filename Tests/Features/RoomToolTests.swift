import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
private final class RoomToolTestContext: ToolContext {
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

@Suite("Room Tool Tests")
@MainActor
struct RoomToolTests {
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

    @Test("RoomTool drag creates 4 connected walls and commits as one batch")
    func roomToolDragCreatesConnectedWalls() {
        let layout = makeLayout()
        let context = RoomToolTestContext(layout: layout)
        let tool = RoomTool(itemID: "wall")

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(2, 2),
            viewPoint: CGPoint(x: 20, y: 20)
        )
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(8, 6),
            viewPoint: CGPoint(x: 80, y: 60)
        )
        tool.handleMove(move, context: context)
        #expect(context.preview?.wallDrawing?.points.count == 5)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(8, 6),
            viewPoint: CGPoint(x: 80, y: 60)
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
        #expect(context.preview == nil)

        let graph = WallGraph(layout: context.layout)
        #expect(graph.nodes.count == 4)
        #expect(graph.nodes.allSatisfy { $0.incidents.count == 2 })
    }

    @Test("RoomTool drag smaller than threshold commits nothing")
    func roomToolDragTooSmallCommitsNothing() {
        let layout = makeLayout()
        let context = RoomToolTestContext(layout: layout)
        let tool = RoomTool(itemID: "wall")

        let press = CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2))
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(worldPoint: SIMD2<Double>(2.1, 2.1))
        tool.handleMove(move, context: context)

        let release = CanvasPointerEvent(worldPoint: SIMD2<Double>(2.1, 2.1))
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.isEmpty)
        #expect(context.switchedTools.contains(.select))
    }
}

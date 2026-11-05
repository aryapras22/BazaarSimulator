import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
private final class NodeDragTestContext: ToolContext {
    var layout: Layout
    var selectionID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var preview: CanvasDragState?
    var appliedEdits: [LayoutEdit] = []
    var switchedTools: [EditorTool] = []
    var activeLayer: EditorLayer = .structure

    init(layout: Layout, selectionID: UUID? = nil) {
        self.layout = layout
        self.selectionID = selectionID
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
    func selectGroup(containing id: UUID, bySize: Bool) {}
    func nudgeSelected(by delta: SIMD2<Double>) {}
    func showTransientHint(_ message: String) {}
}

@Suite("Select Tool Node Drag Tests")
@MainActor
struct SelectToolNodeDragTests {
    private static func makeWall(start: SIMD2<Double>, end: SIMD2<Double>, id: UUID = UUID()) -> LayoutObject {
        let length = simd_distance(start, end)
        let center = (start + end) / 2.0
        let angle = atan2(end.y - start.y, end.x - start.x)
        return LayoutObject(
            id: id,
            kind: .wall,
            label: "Wall",
            placement: Placement(
                center: center,
                sizeM: SIMD2<Double>(length, 0.2),
                rotationRadians: angle
            )
        )
    }

    private static func makeLayout(objects: [LayoutObject]) -> Layout {
        Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(20, 20),
            hall: [SIMD2<Double>(0, 0), SIMD2<Double>(20, 0), SIMD2<Double>(20, 20), SIMD2<Double>(0, 20)],
            lobby: [],
            objects: objects,
            markers: []
        )
    }

    @Test("Dragging a wall graph node moves all incident wall ends")
    func dragNodeMovesIncidentEnds() throws {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let layout = Self.makeLayout(objects: [wall1, wall2])
        let context = NodeDragTestContext(layout: layout)
        let tool = SelectTool()

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 0),
            viewPoint: CGPoint(x: 100, y: 0)
        )
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, -2),
            viewPoint: CGPoint(x: 100, y: -20)
        )
        tool.handleMove(move, context: context)
        #expect(context.preview?.previewPlacements.count == 2)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, -2),
            viewPoint: CGPoint(x: 100, y: -20)
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        let graphAfter = WallGraph(layout: context.layout)
        let ep1 = try #require(graphAfter.endpoints(for: wall1.id))
        let ep2 = try #require(graphAfter.endpoints(for: wall2.id))
        #expect(simd_distance(ep1.end, SIMD2<Double>(10, -2)) < 0.05)
        #expect(simd_distance(ep2.start, SIMD2<Double>(10, -2)) < 0.05)
    }

    @Test("Option-dragging a node detaches target wall from node")
    func optionDragNodeDetachesTargetWall() throws {
        let wall1 = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0))
        let wall2 = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8))
        let layout = Self.makeLayout(objects: [wall1, wall2])
        let context = NodeDragTestContext(layout: layout, selectionID: wall1.id)
        let tool = SelectTool()

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 0),
            viewPoint: CGPoint(x: 100, y: 0),
            modifiers: [.option]
        )
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, -2),
            viewPoint: CGPoint(x: 100, y: -20),
            modifiers: [.option]
        )
        tool.handleMove(move, context: context)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, -2),
            viewPoint: CGPoint(x: 100, y: -20),
            modifiers: [.option]
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        let graphAfter = WallGraph(layout: context.layout)
        let ep1 = try #require(graphAfter.endpoints(for: wall1.id))
        let ep2 = try #require(graphAfter.endpoints(for: wall2.id))
        #expect(simd_distance(ep1.end, SIMD2<Double>(10, -2)) < 0.05)
        #expect(simd_distance(ep2.start, SIMD2<Double>(10, 0)) < 0.05)
    }
}

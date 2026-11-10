import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
private final class HallDragContext: ToolContext {
    var layout: Layout
    var selectionID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var preview: CanvasDragState?
    var appliedEdits: [LayoutEdit] = []

    init(layout: Layout) {
        self.layout = layout
    }

    func setPreview(_ preview: CanvasDragState) { self.preview = preview }
    func clearPreview() { preview = nil }
    func applyEdit(_ edit: LayoutEdit) {
        appliedEdits.append(edit)
        layout = LayoutEditing.apply(edit, to: layout)
    }
    func selectObject(_ id: UUID?) { selectionID = id }
    func selectBooths(_ ids: Set<UUID>, additive: Bool) {}
    func toggleSelection(_ id: UUID) {}
}

@Suite
@MainActor
struct HallEdgesTests {
    private static let hall: [SIMD2<Double>] = [SIMD2(2, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)]

    private static func layout(objects: [LayoutObject] = []) -> Layout {
        Layout(name: "Test", sizeM: SIMD2(14, 10), hall: hall, objects: objects)
    }

    private static func event(at point: SIMD2<Double>) -> CanvasPointerEvent {
        CanvasPointerEvent(
            worldPoint: point,
            viewPoint: CGPoint(x: point.x * 10, y: point.y * 10),
            button: .left,
            modifiers: [],
            hitObjectID: nil,
            pointsPerMetre: 10
        )
    }

    @Test("Pulling the right edge out grows the hall and the world size")
    func rightEdgeGrowsHall() throws {
        let move = try #require(HallEdges.move(edge: 1, to: SIMD2(17, 5), in: Self.layout()))

        #expect(move.hall == [SIMD2(2, 2), SIMD2(17, 2), SIMD2(17, 8), SIMD2(2, 8)])
        let grown = LayoutEditing.apply(move.edit, to: Self.layout())
        #expect(grown.sizeM == SIMD2(17, 10))
    }

    @Test("An edge cannot be dragged past the world origin")
    func edgeStopsAtOrigin() throws {
        let move = try #require(HallEdges.move(edge: 3, to: SIMD2(-6, 5), in: Self.layout()))

        #expect(move.hall[3].x == 0 && move.hall[0].x == 0)
    }

    @Test("Doors on the moved edge travel with it")
    func doorsTravelWithEdge() throws {
        let onEdge = LayoutObject(
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2(12, 5), sizeM: SIMD2(1, 0.2), rotationRadians: .pi / 2)
        )
        let inside = LayoutObject(
            kind: .door,
            label: "D2",
            placement: Placement(center: SIMD2(7, 5), sizeM: SIMD2(1, 0.2))
        )
        let layout = Self.layout(objects: [onEdge, inside])

        let move = try #require(HallEdges.move(edge: 1, to: SIMD2(15, 5), in: layout))

        #expect(move.doorPlacements.keys.contains(onEdge.id))
        #expect(!move.doorPlacements.keys.contains(inside.id))
        let moved = LayoutEditing.apply(move.edit, to: layout)
        #expect(moved.objects.first { $0.id == onEdge.id }?.placement.center == SIMD2(15, 5))
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: moved) == layout)
    }

    @Test("Dragging an edge handle with the select tool applies one undoable edit on release")
    func selectToolDragsHallEdge() {
        let tool = SelectTool()
        let context = HallDragContext(layout: Self.layout())

        tool.handlePress(Self.event(at: SIMD2(12, 5)), context: context)
        tool.handleMove(Self.event(at: SIMD2(14, 5)), context: context)
        #expect(context.preview?.previewHall?[1] == SIMD2(14, 2))
        #expect(context.appliedEdits.isEmpty)
        tool.handleRelease(Self.event(at: SIMD2(14, 5)), context: context)

        #expect(context.appliedEdits.count == 1)
        #expect(context.layout.hall[1] == SIMD2(14, 2))
        #expect(context.preview == nil)
    }
}

import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@MainActor
private final class TestToolContext: ToolContext {
    var layout: Layout
    var selectionID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var preview: CanvasDragState?
    var appliedEdits: [LayoutEdit] = []
    var selectedBoothsHistory: [(ids: Set<UUID>, additive: Bool)] = []
    var toggledIDs: [UUID] = []
    var switchedTools: [EditorTool] = []
    var selectedGroups: [(id: UUID, bySize: Bool)] = []
    var activeLayer: EditorLayer = .booths
    var nudges: [SIMD2<Double>] = []

    init(layout: Layout, selectionID: UUID? = nil, activeLayer: EditorLayer = .booths) {
        self.layout = layout
        self.selectionID = selectionID
        self.activeLayer = activeLayer
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

    func selectObject(_ id: UUID?) {
        selectionID = id
    }

    func selectBooths(_ ids: Set<UUID>, additive: Bool) {
        selectedBoothsHistory.append((ids, additive))
        if additive {
            groupMemberIDs.formUnion(ids)
        } else {
            groupMemberIDs = ids
        }
    }

    func toggleSelection(_ id: UUID) {
        toggledIDs.append(id)
    }

    func switchTool(_ tool: EditorTool) {
        switchedTools.append(tool)
    }

    func selectGroup(containing id: UUID, bySize: Bool) {
        selectedGroups.append((id, bySize))
    }

    func nudgeSelected(by delta: SIMD2<Double>) {
        nudges.append(delta)
    }
}

private struct TestFixture {
    let layout: Layout
    let booth: LayoutObject
    let wall: LayoutObject
}

private func makeLayout() -> TestFixture {
    let booth = LayoutObject(
        id: UUID(),
        kind: .booth,
        label: "N1",
        placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
    )
    let wall = LayoutObject(
        id: UUID(),
        kind: .wall,
        label: "W1",
        placement: Placement(center: SIMD2<Double>(10, 0), sizeM: SIMD2<Double>(10, 0.2))
    )
    let layout = Layout(
        name: "Test",
        sizeM: SIMD2<Double>(30, 30),
        hall: [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(0, 20)
        ],
        objects: [booth, wall]
    )
    return TestFixture(layout: layout, booth: booth, wall: wall)
}

@Suite("Editor Tool Tests")
@MainActor
struct EditorToolTests {
    @Test("SelectTool click selects object and Shift-click toggles")
    func selectToolClickAndToggle() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = SelectTool()

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 100, y: 100),
            hitObjectID: fixture.booth.id
        )
        tool.handlePress(press, context: context)
        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 101, y: 101),
            hitObjectID: fixture.booth.id
        )
        tool.handleRelease(release, context: context)
        #expect(context.selectionID == fixture.booth.id)

        let shiftPress = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 100, y: 100),
            modifiers: .shift,
            hitObjectID: fixture.booth.id
        )
        tool.handlePress(shiftPress, context: context)
        let shiftRelease = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 100, y: 100),
            modifiers: .shift,
            hitObjectID: fixture.booth.id
        )
        tool.handleRelease(shiftRelease, context: context)
        #expect(context.toggledIDs.contains(fixture.booth.id))
    }

    @Test("SelectTool drag past threshold moves object snapped to grid")
    func selectToolDragObject() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout, selectionID: fixture.booth.id)
        let tool = SelectTool()

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 100, y: 100),
            hitObjectID: fixture.booth.id
        )
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(12.12, 10),
            viewPoint: CGPoint(x: 125, y: 100),
            hitObjectID: fixture.booth.id
        )
        tool.handleMove(move, context: context)
        #expect(context.preview?.objectID == fixture.booth.id)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(12.12, 10),
            viewPoint: CGPoint(x: 125, y: 100),
            hitObjectID: fixture.booth.id
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        let updatedBooth = context.layout.objects.first { $0.id == fixture.booth.id }
        #expect(updatedBooth?.placement.center.x == 12.0)
    }

    @Test("SelectTool marquee drag on empty floor selects touched booths")
    func selectToolMarqueeDrag() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = SelectTool()

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(8, 8),
            viewPoint: CGPoint(x: 80, y: 80),
            hitObjectID: nil
        )
        tool.handlePress(press, context: context)

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(12, 12),
            viewPoint: CGPoint(x: 120, y: 120),
            hitObjectID: nil
        )
        tool.handleMove(move, context: context)
        #expect(context.preview?.marqueeStart == SIMD2<Double>(8, 8))

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(12, 12),
            viewPoint: CGPoint(x: 120, y: 120),
            hitObjectID: nil
        )
        tool.handleRelease(release, context: context)

        #expect(context.selectedBoothsHistory.first?.ids.contains(fixture.booth.id) == true)
    }

    @Test("SelectTool double click selects group and escape cancels")
    func selectToolDoubleClickAndEscape() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout, selectionID: fixture.booth.id)
        let tool = SelectTool()

        let dblClick = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 10),
            viewPoint: CGPoint(x: 100, y: 100),
            hitObjectID: fixture.booth.id
        )
        tool.handleDoubleClick(dblClick, context: context)
        #expect(context.selectedGroups.first?.id == fixture.booth.id)

        let handledEscape = tool.handleKey(.escape, context: context)
        #expect(handledEscape)
        #expect(context.selectionID == nil)
    }

    @Test("WallTool places points, responds to length typing and finishes")
    func wallToolPlacementAndFinish() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = WallTool(itemID: "drywall-wall")

        let press1 = CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2))
        tool.handlePress(press1, context: context)
        #expect(tool.drawing?.points.count == 1)

        let move = CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2))
        tool.handleMove(move, context: context)
        #expect(context.preview?.wallCurrentPointer != nil)

        let press2 = CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2))
        tool.handlePress(press2, context: context)
        #expect(tool.drawing?.points.count == 2)

        _ = tool.handleKey(.character("5"), context: context)
        _ = tool.handleKey(.delete, context: context)
        #expect(tool.drawing?.typedLength.isEmpty == true)

        tool.handleDoubleClick(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2)), context: context)
        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
        #expect(context.preview == nil)
    }

    @Test("WallTool typed distance on host wall and return commits point")
    func wallToolTypedDistanceOnHostWall() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5, 0),
            sizeM: SIMD2<Double>(10, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        var layout = Layout(
            id: UUID(),
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: [SIMD2<Double>(0, 0), SIMD2<Double>(20, 0), SIMD2<Double>(20, 20), SIMD2<Double>(0, 20)],
            lobby: [],
            objects: [wall],
            markers: []
        )
        let context = TestToolContext(layout: layout)
        let tool = WallTool(itemID: "drywall-wall")

        let hover = CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 0))
        tool.handleMove(hover, context: context)

        _ = tool.handleKey(.character("3"), context: context)
        #expect(tool.currentPointer != nil)
        #expect(abs((tool.currentPointer?.x ?? 0) - 3.0) < 1e-4)

        _ = tool.handleKey(.returnKey, context: context)
        #expect(tool.drawing?.points.count == 1)
        #expect(abs((tool.drawing?.points.first?.x ?? 0) - 3.0) < 1e-4)

        let moveUp = CanvasPointerEvent(worldPoint: SIMD2<Double>(3, 5))
        tool.handleMove(moveUp, context: context)

        _ = tool.handleKey(.character("4"), context: context)
        _ = tool.handleKey(.returnKey, context: context)
        #expect(tool.drawing?.points.count == 2)
        #expect(abs((tool.drawing?.points[1].y ?? 0) - 4.0) < 1e-4)

        _ = tool.handleKey(.returnKey, context: context)
        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
    }

    @Test("PlaceTool moves candidate and click commits placement")
    func placeToolCandidateAndCommit() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = PlaceTool(source: .catalog("table-rect-4"))

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(15, 15),
            viewPoint: CGPoint(x: 150, y: 150)
        )
        tool.handleMove(move, context: context)
        #expect(context.preview?.placementCandidate != nil)

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(15, 15),
            viewPoint: CGPoint(x: 150, y: 150)
        )
        tool.handlePress(press, context: context)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(15, 15),
            viewPoint: CGPoint(x: 150, y: 150)
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
        #expect(context.preview == nil)
    }

    @Test("DoorTool snaps near wall and commits door")
    func doorToolSnapAndCommit() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = DoorTool(itemID: "door-single")

        let move = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 0.1),
            viewPoint: CGPoint(x: 100, y: 1)
        )
        tool.handleMove(move, context: context)
        #expect(tool.candidate?.isValid == true)

        let press = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 0.1),
            viewPoint: CGPoint(x: 100, y: 1)
        )
        tool.handlePress(press, context: context)

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(10, 0.1),
            viewPoint: CGPoint(x: 100, y: 1)
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
        let placedDoor = context.layout.objects.first { $0.kind == .door }
        #expect(placedDoor != nil)
    }

    @Test("BlockedAreaTool drag creates closed area and commits")
    func blockedAreaToolDrag() {
        let fixture = makeLayout()
        let context = TestToolContext(layout: fixture.layout)
        let tool = BlockedAreaTool()

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
        #expect(context.preview?.drawingStart == SIMD2<Double>(2, 2))

        let release = CanvasPointerEvent(
            worldPoint: SIMD2<Double>(8, 6),
            viewPoint: CGPoint(x: 80, y: 60)
        )
        tool.handleRelease(release, context: context)

        #expect(context.appliedEdits.count == 1)
        #expect(context.switchedTools.contains(.select))
        let area = context.layout.objects.first { $0.kind == .closedArea }
        #expect(area != nil)
    }
}

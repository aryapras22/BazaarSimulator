import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct WallDrawingTests {
    private func makeLayout(
        objects: [LayoutObject] = [],
        hall: [SIMD2<Double>] = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(0, 20)
        ]
    ) -> Layout {
        Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(20, 20),
            hall: hall,
            lobby: [],
            objects: objects,
            markers: []
        )
    }

    @Test("Snapping to a wall end beats the grid")
    func snappingToWallEndBeatsGrid() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.12, 5.0),
            sizeM: SIMD2<Double>(4.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let layout = makeLayout(objects: [wall])

        let wallEnd = SIMD2<Double>(5.12 + 2.0, 5.0) // 7.12, 5.0
        let pointerNearEnd = SIMD2<Double>(7.14, 5.03)

        let snapped = WallDrawing.snappedPoint(pointerNearEnd, from: nil, in: layout, lockAngle: false)
        #expect(abs(snapped.x - wallEnd.x) < 1e-4)
        #expect(abs(snapped.y - wallEnd.y) < 1e-4)
    }

    @Test("Shift locks to 45 degrees")
    func shiftLocksTo45Degrees() {
        let layout = makeLayout()
        let last = SIMD2<Double>(0, 0)
        let pointer = SIMD2<Double>(10, 8)

        let snapped = WallDrawing.snappedPoint(pointer, from: last, in: layout, lockAngle: true)
        let vector = snapped - last
        let angle = atan2(vector.y, vector.x)
        #expect(abs(angle - .pi / 4.0) < 1e-4)
    }

    @Test("A typed 4 gives a 4 m segment along pointer direction")
    func typedLengthPoint() {
        let last = SIMD2<Double>(2, 3)
        let pointer = SIMD2<Double>(12, 3)

        let next = WallDrawing.point(from: last, toward: pointer, length: 4.0)
        #expect(abs(next.x - 6.0) < 1e-4)
        #expect(abs(next.y - 3.0) < 1e-4)
    }

    @Test("Three clicks give two objects with right centres, sizes, and rotations")
    func objectsGeneration() {
        var drawing = WallDrawing()
        drawing.points = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(4, 0),
            SIMD2<Double>(4, 3)
        ]

        let objects = drawing.objects(kind: .wall, thickness: 0.2, height: 3.0, catalogID: "wall")
        #expect(objects.count == 2)

        let first = objects[0]
        #expect(abs(first.placement.center.x - 2.0) < 1e-4)
        #expect(abs(first.placement.center.y - 0.0) < 1e-4)
        #expect(abs(first.placement.sizeM.x - 4.0) < 1e-4)
        #expect(abs(first.placement.sizeM.y - 0.2) < 1e-4)
        #expect(abs(first.placement.rotationRadians - 0.0) < 1e-4)
        #expect(first.heightM == 3.0)

        let second = objects[1]
        #expect(abs(second.placement.center.x - 4.0) < 1e-4)
        #expect(abs(second.placement.center.y - 1.5) < 1e-4)
        #expect(abs(second.placement.sizeM.x - 3.0) < 1e-4)
        #expect(abs(second.placement.sizeM.y - 0.2) < 1e-4)
        #expect(abs(second.placement.rotationRadians - .pi / 2.0) < 1e-4)
        #expect(second.heightM == 3.0)
    }

    @Test("One undo removes the whole chain")
    func undoRemovesWholeChain() {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Test", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()

        let initialCount = viewModel.activeLayout?.objects.count ?? 0
        viewModel.selectTool(.drawWall(itemID: "wall"))

        viewModel.handleWallClick(at: SIMD2<Double>(10, 10), isShiftDown: false)
        viewModel.handleWallClick(at: SIMD2<Double>(14, 10), isShiftDown: false)
        viewModel.handleWallClick(at: SIMD2<Double>(14, 14), isShiftDown: false)
        viewModel.finishWallDrawing()

        let afterCount = viewModel.activeLayout?.objects.count ?? 0
        #expect(afterCount == initialCount + 2)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.activeLayout?.objects.count == initialCount)
    }

    @Test("Placed wall saves without Enter, and Escape only exits the wall tool")
    func escapeExitsWallToolKeepingSavedWall() {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        session.setDraft(
            ProjectDraft(name: "Test", legend: PreviewLayouts.sampleLegend, layouts: [PreviewLayouts.annyeong()]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        let initialCount = viewModel.activeLayout?.objects.count ?? 0

        viewModel.selectTool(.drawWall(itemID: "wall"))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(10, 10)))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(14, 10)))

        #expect(viewModel.activeLayout?.objects.count == initialCount + 1)
        #expect(viewModel.tool == .drawWall(itemID: "wall"))

        _ = viewModel.handleCanvasKey(.escape)
        #expect(viewModel.tool == .select)
        #expect(viewModel.dragState.wallDrawing == nil)
        #expect(viewModel.activeLayout?.objects.count == initialCount + 1)
    }

    @Test("Escape after a single point drops the preview and exits the wall tool")
    func escapeAfterSinglePointExitsWallTool() {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        session.setDraft(
            ProjectDraft(name: "Test", legend: PreviewLayouts.sampleLegend, layouts: [PreviewLayouts.annyeong()]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        let initialCount = viewModel.activeLayout?.objects.count ?? 0

        viewModel.selectTool(.drawWall(itemID: "wall"))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(10, 10)))
        #expect(viewModel.activeLayout?.objects.count == initialCount)

        _ = viewModel.handleCanvasKey(.escape)
        #expect(viewModel.tool == .select)
        #expect(viewModel.dragState.wallDrawing == nil)
        #expect(viewModel.activeLayout?.objects.count == initialCount)
    }

    @Test("Switching layer mid-wall drops the half-drawn chain")
    func switchingLayerDropsWallPreview() {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        session.setDraft(
            ProjectDraft(name: "Test", legend: PreviewLayouts.sampleLegend, layouts: [PreviewLayouts.annyeong()]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        viewModel.selectTool(.drawWall(itemID: "wall"))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(10, 10)))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(14, 10)))

        viewModel.selectLayer(.booths)

        #expect(viewModel.tool == .select)
        #expect(viewModel.wallDrawing == nil)
        #expect(viewModel.dragState.wallDrawing == nil)
    }

    @Test("The live angle is the turn from the previous wall, or the direction from the x axis")
    func liveAngle() {
        let origin = SIMD2<Double>(0, 0)
        #expect(WallDrawingRenderer.angleDegrees(from: origin, to: SIMD2(0, 5), previous: nil) == 90)
        #expect(WallDrawingRenderer.angleDegrees(from: origin, to: SIMD2(5, 0), previous: SIMD2(0, 5)) == 90)
        #expect(WallDrawingRenderer.angleDegrees(from: origin, to: SIMD2(5, 0), previous: SIMD2(-5, 0)) == 180)
    }
}

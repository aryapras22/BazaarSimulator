import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("WallTool Tests")
@MainActor
struct WallToolTests {
    private func makeViewModel(objects: [LayoutObject] = []) -> LayoutEditorViewModel {
        let layout = Layout(
            id: UUID(),
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: [
                SIMD2<Double>(0, 0),
                SIMD2<Double>(20, 0),
                SIMD2<Double>(20, 20),
                SIMD2<Double>(0, 20)
            ],
            lobby: [],
            objects: objects,
            markers: []
        )
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        session.setDraft(
            ProjectDraft(name: "Test", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        viewModel.selectTool(.drawWall(itemID: "drywall-wall"))
        return viewModel
    }

    @Test("WallTool saves each segment immediately, ends chain on double-click, and exits only on escape")
    func wallToolPlacementAndFinish() {
        let viewModel = makeViewModel()

        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2)))
        #expect(viewModel.dragState.wallDrawing?.points.count == 1)
        #expect(viewModel.activeLayout?.objects.isEmpty == true)

        viewModel.handlePointerMove(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2)))
        #expect(viewModel.dragState.wallCurrentPointer != nil)

        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2)))
        #expect(viewModel.activeLayout?.objects.count == 1)
        #expect(viewModel.tool == .drawWall(itemID: "drywall-wall"))
        #expect(viewModel.dragState.wallDrawing?.points == [SIMD2<Double>(6, 2)])
        #expect(viewModel.dragState.wallDrawing?.previousPoint == SIMD2<Double>(2, 2))

        _ = viewModel.handleCanvasKey(.character("5"))
        _ = viewModel.handleCanvasKey(.delete)
        #expect(viewModel.dragState.wallDrawing?.typedLength.isEmpty == true)

        viewModel.handlePointerDoubleClick(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2)))
        #expect(viewModel.dragState.wallDrawing == nil)
        #expect(viewModel.dragState.wallCurrentPointer == nil)
        #expect(viewModel.tool == .drawWall(itemID: "drywall-wall"))
        #expect(viewModel.activeLayout?.objects.count == 1)

        _ = viewModel.handleCanvasKey(.escape)
        #expect(viewModel.tool == .select)
        #expect(viewModel.activeLayout?.objects.count == 1)
    }

    @Test("WallTool typed distance on host wall and return commits segment immediately")
    func wallToolTypedDistanceOnHostWall() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5, 0),
            sizeM: SIMD2<Double>(10, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let viewModel = makeViewModel(objects: [wall])

        viewModel.handlePointerMove(CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 0)))

        _ = viewModel.handleCanvasKey(.character("3"))
        #expect(viewModel.dragState.wallCurrentPointer != nil)
        #expect(abs((viewModel.dragState.wallCurrentPointer?.x ?? 0) - 3.0) < 1e-4)

        _ = viewModel.handleCanvasKey(.returnKey)
        #expect(viewModel.dragState.wallDrawing?.points.count == 1)
        #expect(abs((viewModel.dragState.wallDrawing?.points.first?.x ?? 0) - 3.0) < 1e-4)

        viewModel.handlePointerMove(CanvasPointerEvent(worldPoint: SIMD2<Double>(3, 5)))

        _ = viewModel.handleCanvasKey(.character("4"))
        _ = viewModel.handleCanvasKey(.returnKey)
        #expect(viewModel.activeLayout?.objects.count == 3)
        #expect(viewModel.tool == .drawWall(itemID: "drywall-wall"))
        #expect(abs((viewModel.dragState.wallDrawing?.points.first?.y ?? 0) - 4.0) < 1e-4)

        _ = viewModel.handleCanvasKey(.escape)
        #expect(viewModel.tool == .select)
        #expect(viewModel.dragState.wallDrawing == nil)
    }

    @Test("WallTool closing loop commits closing wall and stays in WallTool")
    func wallToolClosesLoopAndStaysActive() {
        let viewModel = makeViewModel()

        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(2, 2)))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 2)))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(6, 6)))
        viewModel.handlePointerPress(CanvasPointerEvent(worldPoint: SIMD2<Double>(2.05, 2.05)))

        #expect(viewModel.activeLayout?.objects.count == 3)
        #expect(viewModel.dragState.wallDrawing == nil)
        #expect(viewModel.dragState.wallCurrentPointer == nil)
        #expect(viewModel.tool == .drawWall(itemID: "drywall-wall"))
    }
}

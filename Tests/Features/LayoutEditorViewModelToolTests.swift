import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelToolTests {
    private func makeContext() -> LayoutEditorViewModelTests.TestContext {
        LayoutEditorViewModelTests.makeContext()
    }

    @Test("Add blocked area inserts object, selects it, and reverts to select tool")
    func addBlockedAreaInsertsAndSelects() throws {
        let context = makeContext()
        context.viewModel.selectTool(.blockedArea)
        #expect(context.viewModel.tool == .blockedArea)

        let placement = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4)
        )
        context.viewModel.addBlockedArea(placement)

        #expect(context.viewModel.tool == .select)
        let selected = try #require(context.viewModel.selectedObject)
        #expect(selected.kind == .closedArea)
        #expect(selected.label == "Restricted area")
        #expect(selected.placement == placement)

        context.viewModel.undo()
        #expect(context.viewModel.selectedObject == nil)
        #expect(context.viewModel.activeLayout?.objects.contains { $0.id == selected.id } == false)
    }

    @Test("Switching tools keeps the inspector edit already applied")
    func toolSwitchKeepsInspectorEdit() throws {
        let context = makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 5.0 }

        context.viewModel.selectTool(.blockedArea)

        #expect(context.viewModel.tool == .blockedArea)
        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.placement.sizeM.x == 5.0)
    }

    @Test("Switching layers resets tool to select")
    func switchingLayersResetsTool() {
        let context = makeContext()
        context.viewModel.selectLayer(.structure)
        context.viewModel.selectTool(.blockedArea)
        #expect(context.viewModel.tool == .blockedArea)

        context.viewModel.selectLayer(.booths)
        #expect(context.viewModel.tool == .select)
    }

    @Test("Finish resizing object updates placement and inspector draft")
    func finishResizingObjectUpdatesPlacementAndDraft() throws {
        let context = makeContext()
        let placement = Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(4, 4))
        context.viewModel.addBlockedArea(placement)
        let area = try #require(context.viewModel.selectedObject)

        let newPlacement = Placement(center: SIMD2<Double>(10.5, 10), sizeM: SIMD2<Double>(5, 4))
        context.viewModel.finishResizingObject(id: area.id, to: newPlacement)

        let updated = try #require(context.viewModel.selectedObject)
        #expect(updated.placement == newPlacement)
        #expect(context.viewModel.inspectorDraft?.widthM == 5.0)
        #expect(context.viewModel.inspectorDraft?.lengthM == 4.0)

        context.viewModel.undo()
        let reverted = try #require(context.viewModel.selectedObject)
        #expect(reverted.placement == placement)
    }
}

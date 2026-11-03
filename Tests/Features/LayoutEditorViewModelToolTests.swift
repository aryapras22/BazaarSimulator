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
        #expect(selected.label == "Blocked area")
        #expect(selected.placement == placement)

        context.viewModel.undo()
        #expect(context.viewModel.selectedObject == nil)
        #expect(context.viewModel.activeLayout?.objects.contains { $0.id == selected.id } == false)
    }

    @Test("Tool switch with unsaved draft asks for confirmation")
    func toolSwitchWithUnsavedChangesAsksConfirmation() throws {
        let context = makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        context.viewModel.inspectorDraft?.widthM = 5.0

        context.viewModel.selectTool(.blockedArea)

        #expect(context.viewModel.pendingAction == .switchTool(.blockedArea))
        #expect(context.viewModel.tool == .select)

        context.viewModel.confirmPendingActionWithDiscard()
        #expect(context.viewModel.tool == .blockedArea)
    }

    @Test("Switching to flow tab resets tool to select")
    func switchingToFlowTabResetsTool() {
        let context = makeContext()
        context.viewModel.selectTool(.blockedArea)
        #expect(context.viewModel.tool == .blockedArea)

        context.viewModel.selectTab(.flow)
        #expect(context.viewModel.tool == .select)
    }
}

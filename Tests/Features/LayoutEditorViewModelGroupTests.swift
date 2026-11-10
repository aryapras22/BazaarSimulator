import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelGroupTests {
    struct TestContext {
        let viewModel: LayoutEditorViewModel
        let layout: Layout
    }

    static func makeContext(layer: EditorLayer = .booths) -> TestContext {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.activeLayer = layer
        viewModel.refreshDerivedState()
        return TestContext(viewModel: viewModel, layout: layout)
    }

    private func booth(labelled label: String, in layout: Layout) throws -> LayoutObject {
        try #require(layout.objects.first { $0.label == label })
    }

    @Test("Double-click selects the name group and Option-double-click the size group")
    func doubleClickSelectsGroups() throws {
        let context = Self.makeContext()
        let target = try booth(labelled: "A5", in: context.layout)

        context.viewModel.selectGroup(containing: target.id, bySize: false)
        #expect(context.viewModel.groupSelectionTitle == "Group A · 112 booths")

        context.viewModel.selectGroup(containing: target.id, bySize: true)
        #expect(context.viewModel.groupSelectionTitle == "Size 2.5 × 2.5 m · 150 booths")
        #expect(context.viewModel.selectionID == nil)
    }

    @Test("Shift-click builds a custom selection and a second Shift-click removes a member")
    func shiftClickTogglesMembers() throws {
        let context = Self.makeContext()
        let ids = try ["A1", "A2", "A3"].map { try booth(labelled: $0, in: context.layout).id }

        ids.forEach { context.viewModel.toggleBoothInSelection($0) }
        #expect(context.viewModel.groupSelectionTitle == "3 booths")

        context.viewModel.toggleBoothInSelection(ids[0])
        #expect(context.viewModel.groupSelectionTitle == "2 booths")

        context.viewModel.toggleBoothInSelection(ids[1])
        #expect(context.viewModel.selectionID == ids[2])
        #expect(context.viewModel.groupSelection == nil)
    }

    @Test("Selecting one booth after a group replaces the group selection")
    func singleSelectionReplacesGroup() throws {
        let context = Self.makeContext()
        let target = try booth(labelled: "A5", in: context.layout)
        context.viewModel.selectGroup(containing: target.id, bySize: false)

        context.viewModel.selectObject(target.id)

        #expect(context.viewModel.groupSelection == nil)
        #expect(context.viewModel.selectionID == target.id)
    }

    @Test("Clearing the selection leaves no group selected")
    func clearingSelectionClearsGroup() throws {
        let context = Self.makeContext()
        let target = try booth(labelled: "A5", in: context.layout)
        context.viewModel.selectGroup(containing: target.id, bySize: false)

        context.viewModel.selectObject(nil)

        #expect(context.viewModel.groupSelection == nil)
    }

    @Test("An arrow key nudge with a group selected moves nothing")
    func nudgeWithGroupSelectedMovesNothing() throws {
        let context = Self.makeContext()
        let target = try booth(labelled: "A5", in: context.layout)
        context.viewModel.selectGroup(containing: target.id, bySize: false)

        context.viewModel.nudgeSelected(by: SIMD2<Double>(1, 0))

        #expect(context.viewModel.activeLayout == context.layout)
        #expect(!context.viewModel.canUndo)
    }

    @Test("Context delete on a group member asks to delete the whole group")
    func contextDeleteOnGroupMemberKeepsGroupSelection() throws {
        let context = Self.makeContext()
        let target = try booth(labelled: "A5", in: context.layout)
        context.viewModel.selectGroup(containing: target.id, bySize: false)
        let memberCount = context.viewModel.groupMemberIDs.count

        context.viewModel.handleContextAction(.delete(target.id))

        #expect(context.viewModel.groupMemberIDs.count == memberCount)
        #expect(context.viewModel.pendingGroupDelete == memberCount)
        #expect(context.viewModel.activeLayout == context.layout)
    }

    @Test("Arrow keys are left to the canvas so Shift can widen the nudge step")
    func selectToolLeavesArrowKeysToTheCanvas() {
        let context = Self.makeContext()

        #expect(!context.viewModel.handleCanvasKey(.leftArrow))
        #expect(!context.viewModel.handleCanvasKey(.upArrow))
    }

    @Test("A group edit changes every member as one undo step")
    func groupEditIsOneUndoStep() throws {
        let context = Self.makeContext()
        let viewModel = context.viewModel
        let target = try booth(labelled: "A5", in: context.layout)
        let lifestyle = try #require(PreviewLayouts.sampleLegend.entries.last)
        viewModel.selectGroup(containing: target.id, bySize: false)
        viewModel.editGroupDraft { $0.category = .set(lifestyle.id) }

        let members = viewModel.selectedGroupMembers
        #expect(members.count == 112)
        #expect(members.allSatisfy { $0.categoryID == lifestyle.id })
        viewModel.undo()
        #expect(viewModel.activeLayout == context.layout)
        #expect(!viewModel.canUndo)
    }

    @Test("Deleting a group asks for confirmation, then removes every member")
    func groupDeleteConfirms() throws {
        let context = Self.makeContext()
        let viewModel = context.viewModel
        let target = try booth(labelled: "I1", in: context.layout)
        viewModel.selectGroup(containing: target.id, bySize: false)

        viewModel.deleteCurrentSelection()
        #expect(viewModel.pendingGroupDelete == 9)
        #expect(viewModel.activeLayout == context.layout)

        viewModel.deleteGroupSelection()
        #expect(viewModel.activeLayout?.objects.count == context.layout.objects.count - 9)
        #expect(viewModel.groupSelection == nil)

        viewModel.undo()
        #expect(viewModel.activeLayout == context.layout)
    }

    @Test("Walls can be multi-selected on Structure and deleted at once, and booths cannot")
    func structureMultiSelectDeletes() {
        let context = Self.makeContext(layer: .structure)
        let viewModel = context.viewModel
        let layout = context.layout
        let walls = layout.objects.filter { $0.kind == .wall }.prefix(2).map(\.id)
        let booth = layout.objects.first { $0.kind == .booth }?.id

        viewModel.selectBooths(Set(walls + [booth].compactMap { $0 }), additive: false)

        #expect(viewModel.groupSelection?.memberIDs == Set(walls))
        viewModel.deleteCurrentSelection()
        #expect(viewModel.pendingGroupDelete == nil)
        #expect(viewModel.activeLayout?.objects.count == layout.objects.count - walls.count)
        #expect(viewModel.groupSelection == nil)
    }

    @Test("Groups list is visible when nothing is selected on booths layer")
    func groupsListVisibilityAndRows() {
        let context = Self.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)

        #expect(viewModel.isGroupsListVisible)
        #expect(viewModel.nameGroupRows.map(\.title) == ["A", "B", "C", "F", "I"])
        #expect(viewModel.sizeGroupRows.map(\.count) == [150, 42, 9, 8])

        viewModel.selectLayer(.structure)
        #expect(!viewModel.isGroupsListVisible)
    }

    @Test("Duplicating a booth keeps its prefix, adding booths uses prefix N")
    func boothDuplicationAndAdditionLabels() throws {
        let context = Self.makeContext()
        let viewModel = context.viewModel
        let target = try booth(labelled: "A5", in: context.layout)

        viewModel.selectObject(target.id)
        viewModel.duplicateSelected()
        #expect(viewModel.selectedObject?.label == "A113")

        viewModel.addObject(kind: .booth, at: SIMD2<Double>(10, 10))
        #expect(viewModel.selectedObject?.label == "N1")

        viewModel.addObject(kind: .booth, at: SIMD2<Double>(14, 10))
        #expect(viewModel.selectedObject?.label == "N2")
    }
}

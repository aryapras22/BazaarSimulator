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

    static func makeContext() -> TestContext {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
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
}

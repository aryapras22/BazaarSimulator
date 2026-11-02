import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelTests {
    struct TestContext {
        let viewModel: LayoutEditorViewModel
        let session: ProjectSession
        let layout: Layout
    }

    static func makeContext() -> TestContext {
        let session = ProjectSession()
        let project = session.createProject(named: "Test Market")
        let layout = PreviewLayouts.smallMarket()
        let draft = ProjectDraft(
            name: "Test Market",
            legend: PreviewLayouts.sampleLegend,
            layouts: [layout]
        )
        session.setDraft(draft, for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        return TestContext(viewModel: viewModel, session: session, layout: layout)
    }

    @Test("Selecting a booth fills the inspector draft")
    func selectingBoothFillsDraft() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)

        #expect(context.viewModel.selectionID == booth.id)
        #expect(context.viewModel.inspectorDraft?.objectID == booth.id)
        #expect(context.viewModel.inspectorDraft?.widthM == booth.placement.sizeM.x)
    }

    @Test("Switching tabs clears the selection")
    func switchingTabsClearsSelection() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        #expect(context.viewModel.selectionID == booth.id)

        context.viewModel.selectTab(.flow)

        #expect(context.viewModel.tab == .flow)
        #expect(context.viewModel.selectionID == nil)
        #expect(context.viewModel.inspectorDraft == nil)
    }

    @Test("Flow tab ignores a booth click")
    func flowTabIgnoresBoothClick() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectTab(.flow)

        context.viewModel.selectObject(booth.id)

        #expect(context.viewModel.selectionID == nil)
    }

    @Test("Drag end commits one edit, snaps to 0.25 m grid, and writes the session")
    func dragEndCommitsEditAndWritesSession() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.finishDraggingObject(id: booth.id, deltaWorld: SIMD2<Double>(1.12, 0.38))

        #expect(context.viewModel.canUndo)
        let moved = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(abs(moved.placement.center.x - 9.0) < 1e-6)
        #expect(abs(moved.placement.center.y - 8.5) < 1e-6)
    }

    @Test("Delete removes the selected object and can be undone")
    func deleteRemovesObjectAndCanBeUndone() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.deleteSelected()

        #expect(context.viewModel.selectionID == nil)
        #expect(context.viewModel.activeLayout?.objects.contains { $0.id == booth.id } == false)

        context.viewModel.undo()

        #expect(context.viewModel.activeLayout?.objects.contains { $0.id == booth.id } == true)
    }

    @Test("Duplicate adds a copy offset by 1 m in both axes")
    func duplicateAddsOffsetCopy() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        let countBefore = context.layout.objects.count

        context.viewModel.selectObject(booth.id)
        context.viewModel.duplicateSelected()

        let updatedObjects = try #require(context.viewModel.activeLayout?.objects)
        #expect(updatedObjects.count == countBefore + 1)
        let duplicated = try #require(context.viewModel.selectedObject)
        #expect(duplicated.id != booth.id)
        #expect(duplicated.placement.center == booth.placement.center + SIMD2<Double>(1.0, 1.0))
    }

    @Test("Add Booth Here adds an unassigned 2 x 2 booth with inferred open sides")
    func addBoothHereAddsUnassignedBoothWithInferredSides() throws {
        let context = Self.makeContext()

        context.viewModel.addObject(kind: .booth, at: SIMD2<Double>(20.1, 10.1))

        let added = try #require(context.viewModel.selectedObject)
        #expect(added.kind == .booth)
        #expect(added.categoryID == nil)
        #expect(added.placement.sizeM == SIMD2<Double>(2.0, 2.0))
        #expect(added.placement.center == SIMD2<Double>(20.0, 10.0))
        #expect(added.openSides == .all)
    }

    @Test("Hovering does not refresh issues")
    func hoveringDoesNotRefreshIssues() throws {
        let context = Self.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let first = try #require(booths.first)
        let second = try #require(booths.dropFirst().first)

        context.viewModel.hoverID = first.id
        #expect(context.viewModel.issues.isEmpty)

        var moved = second
        moved.placement.center = first.placement.center
        context.viewModel.commitEdit(.replace(before: second, after: moved))

        #expect(context.viewModel.issues.contains { $0.kind == .overlappingObjects })
    }

    @Test("Context delete on another object deletes that object")
    func contextDeleteOnAnotherObjectDeletesTarget() throws {
        let context = Self.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let boothA = try #require(booths.first)
        let boothB = try #require(booths.dropFirst().first)

        context.viewModel.selectObject(boothA.id)
        context.viewModel.handleContextAction(.delete(boothB.id))

        let remainingIDs = try #require(context.viewModel.activeLayout?.objects.map(\.id))
        #expect(remainingIDs.contains(boothA.id))
        #expect(!remainingIDs.contains(boothB.id))
    }

    @Test("Context action on another object with unsaved changes asks first")
    func contextActionOnAnotherObjectWithUnsavedChangesAsksFirst() throws {
        let context = Self.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let boothA = try #require(booths.first)
        let boothB = try #require(booths.dropFirst().first)

        context.viewModel.selectObject(boothA.id)
        context.viewModel.inspectorDraft?.widthM = 4.0
        context.viewModel.handleContextAction(.delete(boothB.id))

        #expect(context.viewModel.pendingAction == .selectObject(boothB.id))
        let remainingIDs = try #require(context.viewModel.activeLayout?.objects.map(\.id))
        #expect(remainingIDs.contains(boothB.id))
    }

    @Test("Redo with unsaved changes asks first")
    func redoWithUnsavedChangesAsksFirst() throws {
        let context = Self.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.nudgeSelected(by: SIMD2<Double>(1, 0))
        context.viewModel.undo()
        #expect(context.viewModel.canRedo)

        context.viewModel.inspectorDraft?.widthM = 4.0
        context.viewModel.redo()

        #expect(context.viewModel.pendingAction == .performRedo)
    }

    @Test("Duplicate labels never repeat")
    func duplicateLabelsNeverRepeat() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let booths = (1...5).map { number in
            LayoutObject(
                kind: .booth,
                label: "B\(number)",
                placement: Placement(center: SIMD2<Double>(Double(number) * 3, 5), sizeM: SIMD2<Double>(2, 2))
            )
        }
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(25, 25), objects: booths)
        session.setDraft(ProjectDraft(name: "Test", layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)

        viewModel.selectObject(booths[2].id)
        viewModel.deleteSelected()

        viewModel.selectObject(booths[0].id)
        viewModel.duplicateSelected()

        #expect(viewModel.selectedObject?.label == "B6")
    }

    @Test("Saving inspector changes updates issues for the saved layout")
    func savingInspectorChangesUpdatesIssues() throws {
        let context = Self.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let boothA = try #require(booths.first)

        context.viewModel.selectObject(boothA.id)
        context.viewModel.inspectorDraft?.widthM = 12.0
        context.viewModel.saveInspectorChanges()

        #expect(context.viewModel.issues.contains { $0.kind == .overlappingObjects })
    }
}

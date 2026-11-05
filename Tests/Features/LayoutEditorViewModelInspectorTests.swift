import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelInspectorTests {
    @Test("Save is disabled until the draft changes")
    func saveDisabledUntilDraftChanges() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        #expect(!context.viewModel.isSaveChangesEnabled)

        context.viewModel.inspectorDraft?.widthM = 3.0
        #expect(context.viewModel.isSaveChangesEnabled)
    }

    @Test("Save commits one undoable edit and updates the session")
    func saveCommitsOneUndoableEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.inspectorDraft?.widthM = 3.5
        context.viewModel.saveInspectorChanges()

        #expect(!context.viewModel.isSaveChangesEnabled)
        #expect(context.viewModel.canUndo)
        let savedBooth = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(savedBooth.placement.sizeM.x == 3.5)
    }

    @Test("Changing selection with unsaved changes requests confirmation; Discard drops and Save keeps")
    func changingSelectionWithUnsavedChanges() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let firstBooth = try #require(booths.first)
        let secondBooth = try #require(booths.dropFirst().first)

        context.viewModel.selectObject(firstBooth.id)
        context.viewModel.inspectorDraft?.widthM = 4.0

        context.viewModel.selectObject(secondBooth.id)
        #expect(context.viewModel.pendingAction == .selectObject(secondBooth.id))
        #expect(context.viewModel.selectionID == firstBooth.id)

        context.viewModel.confirmPendingActionWithDiscard()
        #expect(context.viewModel.selectionID == secondBooth.id)
        let unchangedFirst = try #require(context.viewModel.activeLayout?.objects.first { $0.id == firstBooth.id })
        #expect(unchangedFirst.placement.sizeM.x == firstBooth.placement.sizeM.x)

        context.viewModel.inspectorDraft?.widthM = 4.5
        context.viewModel.selectObject(firstBooth.id)
        context.viewModel.confirmPendingActionWithSave()
        #expect(context.viewModel.selectionID == firstBooth.id)
        let updatedSecond = try #require(context.viewModel.activeLayout?.objects.first { $0.id == secondBooth.id })
        #expect(updatedSecond.placement.sizeM.x == 4.5)
    }

    @Test("An invalid size disables Save")
    func invalidSizeDisablesSave() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.inspectorDraft?.widthM = 0.2

        #expect(!context.viewModel.isInspectorDraftValid)
        #expect(!context.viewModel.isSaveChangesEnabled)
    }

    @Test("Toggling the screen-right edge of a booth rotated 90 degrees toggles its own top side")
    func toggleRotatedScreenEdgeMapsToLocalSide() {
        let initial: OpenSides = []

        let updated = initial.toggling(
            screenSide: .right,
            rotationDegrees: 90,
            allowsMultiple: true
        )

        #expect(updated == .top)
    }

    @Test("Use advice sets the draft direction and Save applies it")
    func useAdviceSetsDraftDirectionAndSaves() throws {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let doorNW = try #require(
            context.layout.objects.first { $0.kind == .door && $0.label == "Door NW" }
        )

        context.viewModel.selectObject(doorNW.id)
        #expect(context.viewModel.currentDoorAdvice?.suggestedDirection == .entrance)

        context.viewModel.applyDoorAdvice()
        #expect(context.viewModel.inspectorDraft?.doorDirection == .entrance)
        #expect(context.viewModel.isSaveChangesEnabled)

        context.viewModel.saveInspectorChanges()
        let savedDoor = try #require(
            context.viewModel.activeLayout?.objects.first { $0.id == doorNW.id }
        )
        #expect(savedDoor.doorFlow?.direction == .entrance)
    }

    @Test("Selecting an imported booth leaves Save disabled")
    func selectingImportedBoothLeavesSaveDisabled() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        let firstBooth = try #require(layout.objects.first { $0.kind == .booth })

        viewModel.selectObject(firstBooth.id)

        #expect(!viewModel.isSaveChangesEnabled)
    }

    @Test("Selecting a blocked area fills the draft")
    func selectingBlockedAreaFillsDraft() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)

        #expect(viewModel.inspectorDraft?.kind == .closedArea)
        #expect(viewModel.inspectorTitle == "Blocked area")
    }

    @Test("Renaming a blocked area saves the label")
    func renamingBlockedAreaSavesLabel() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.inspectorDraft?.label = "Storage"
        viewModel.saveInspectorChanges()

        #expect(viewModel.selectedObject?.label == "Storage")
    }

    @Test("A blocked area narrower than 0.5 m cannot be saved")
    func blockedAreaUnderMinimumCannotBeSaved() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.inspectorDraft?.widthM = 0.3

        #expect(!viewModel.isSaveChangesEnabled)
    }

    private func makeAnnyeongContext() throws -> (LayoutEditorViewModel, LayoutObject) {
        let layout = PreviewLayouts.annyeong()
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        let area = try #require(layout.objects.first { $0.kind == .closedArea })
        return (viewModel, area)
    }

    @Test("Saving wall length in inspector updates wall length and stretches neighbours")
    func savingWallLengthInInspectorStretchesNeighbours() throws {
        let wall1 = LayoutObject(
            kind: .wall,
            label: "Wall 1",
            placement: Placement(center: SIMD2<Double>(5, 0), sizeM: SIMD2<Double>(10, 0.2))
        )
        let wall2 = LayoutObject(
            kind: .wall,
            label: "Wall 2",
            placement: Placement(center: SIMD2<Double>(10, 4), sizeM: SIMD2<Double>(8, 0.2), rotationRadians: .pi / 2)
        )
        let layout = Layout(name: "WallTest", sizeM: SIMD2<Double>(20, 20), objects: [wall1, wall2])
        let session = ProjectSession()
        let project = session.createProject(named: "WallProject")
        session.setDraft(
            ProjectDraft(name: "WallProject", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, onBack: {})
        viewModel.selectObject(wall1.id)
        #expect(viewModel.inspectorDraft?.widthM == 10.0)

        viewModel.inspectorDraft?.widthM = 15.0
        #expect(viewModel.isSaveChangesEnabled)
        viewModel.saveInspectorChanges()

        let savedWall1 = try #require(viewModel.activeLayout?.objects.first { $0.id == wall1.id })
        #expect(abs(savedWall1.placement.sizeM.x - 15.0) < 0.05)

        let active = try #require(viewModel.activeLayout)
        let graph = WallGraph(layout: active)
        let ep1 = try #require(graph.endpoints(for: wall1.id))
        let ep2 = try #require(graph.endpoints(for: wall2.id))
        #expect(simd_distance(ep1.end, SIMD2<Double>(15, 0)) < 0.05)
        #expect(simd_distance(ep2.start, SIMD2<Double>(15, 0)) < 0.05)
    }
}

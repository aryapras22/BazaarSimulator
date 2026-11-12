import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelInspectorTests {
    @Test("A valid inspector edit applies at once as an undoable edit")
    func inspectorEditAppliesAtOnce() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        #expect(!context.viewModel.canUndo)
        context.viewModel.editInspectorDraft { $0.widthM = 3.5 }

        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.placement.sizeM.x == 3.5)
        #expect(context.viewModel.canUndo)
    }

    @Test("A booth starts at attractiveness 1, a whole number from 1 to 5 applies and a negative or fractional one does not")
    func attractivenessEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        #expect(booth.attractiveness == 1)

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.attractiveness = 3 }
        context.viewModel.editInspectorDraft { $0.attractiveness = -1 }
        context.viewModel.editInspectorDraft { $0.attractiveness = 2.5 }

        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.attractiveness == 3)
    }

    @Test("A block can be made round from the inspector, while a booth stays rectangular")
    func inspectorShapeEdit() throws {
        let structure = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let booths = LayoutEditorViewModelTests.makeContext()
        let block = try #require(structure.layout.objects.first { $0.kind == .block })
        let booth = try #require(booths.layout.objects.first { $0.kind == .booth })

        structure.viewModel.selectObject(block.id)
        structure.viewModel.editInspectorDraft { $0.shape = .round }
        booths.viewModel.selectObject(booth.id)
        booths.viewModel.editInspectorDraft { $0.shape = .round }

        #expect(structure.viewModel.activeLayout?.objects.first { $0.id == block.id }?.placement.shape == .round)
        #expect(booths.viewModel.activeLayout?.objects.first { $0.id == booth.id }?.placement.shape == .rect)
    }

    @Test("Several edits to one object undo in one step")
    func inspectorEditsCoalesce() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 3.0 }
        context.viewModel.editInspectorDraft { $0.widthM = 3.5 }
        context.viewModel.editInspectorDraft { $0.label = "Renamed" }
        context.viewModel.undo()

        #expect(context.viewModel.activeLayout == context.layout)
        #expect(!context.viewModel.canUndo)
    }

    @Test("Changing selection keeps the edit already applied")
    func changingSelectionKeepsEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let firstBooth = try #require(booths.first)
        let secondBooth = try #require(booths.dropFirst().first)

        context.viewModel.selectObject(firstBooth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 4.0 }
        context.viewModel.selectObject(secondBooth.id)

        #expect(context.viewModel.selectionID == secondBooth.id)
        let first = try #require(context.viewModel.activeLayout?.objects.first { $0.id == firstBooth.id })
        #expect(first.placement.sizeM.x == 4.0)
    }

    @Test("An invalid size stays in the draft and never reaches the layout")
    func invalidSizeIsNotApplied() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 0.2 }

        #expect(!context.viewModel.isInspectorDraftValid)
        #expect(context.viewModel.activeLayout == context.layout)
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

    @Test("Use advice applies the suggested direction")
    func useAdviceAppliesDirection() throws {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        let doorNW = try #require(
            context.layout.objects.first { $0.kind == .door && $0.label == "Door NW" }
        )

        context.viewModel.selectObject(doorNW.id)
        #expect(context.viewModel.currentDoorAdvice?.suggestedDirection == .entrance)

        context.viewModel.applyDoorAdvice()
        #expect(context.viewModel.inspectorDraft?.doorDirection == .entrance)
        let savedDoor = try #require(
            context.viewModel.activeLayout?.objects.first { $0.id == doorNW.id }
        )
        #expect(savedDoor.doorFlow?.direction == .entrance)
    }

    @Test("Selecting an imported booth changes nothing")
    func selectingImportedBoothChangesNothing() throws {
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

        #expect(!viewModel.canUndo)
    }

    @Test("Selecting a blocked area fills the draft")
    func selectingBlockedAreaFillsDraft() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)

        #expect(viewModel.inspectorDraft?.kind == .closedArea)
        #expect(viewModel.inspectorTitle == "Restricted area")
    }

    @Test("Renaming a blocked area applies the label")
    func renamingBlockedAreaAppliesLabel() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.editInspectorDraft { $0.label = "Storage" }

        #expect(viewModel.selectedObject?.label == "Storage")
    }

    @Test("A blocked area narrower than 0.5 m is not applied")
    func blockedAreaUnderMinimumIsNotApplied() throws {
        let (viewModel, area) = try makeAnnyeongContext()

        viewModel.selectObject(area.id)
        viewModel.editInspectorDraft { $0.widthM = 0.3 }

        #expect(viewModel.selectedObject?.placement.sizeM == area.placement.sizeM)
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

    @Test("Editing wall length in the inspector updates wall length and stretches neighbours")
    func editingWallLengthInInspectorStretchesNeighbours() throws {
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

        viewModel.editInspectorDraft { $0.widthM = 15.0 }

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

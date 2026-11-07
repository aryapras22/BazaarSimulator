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

    static func makeContext(layer: EditorLayer = .booths) -> TestContext {
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
        viewModel.activeLayer = layer
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

    @Test("Switching layers clears the selection")
    func switchingLayersClearsSelection() throws {
        let context = Self.makeContext()
        context.viewModel.selectLayer(.booths)
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        #expect(context.viewModel.selectionID == booth.id)

        context.viewModel.selectLayer(.structure)

        #expect(context.viewModel.activeLayer == .structure)
        #expect(context.viewModel.selectionID == nil)
        #expect(context.viewModel.inspectorDraft == nil)
    }

    @Test("Structure layer ignores a booth click")
    func structureLayerIgnoresBoothClick() throws {
        let context = Self.makeContext(layer: .structure)
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })

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
        let layout = try #require(context.viewModel.activeLayout)
        #expect(added.kind == .booth)
        #expect(added.categoryID == nil)
        #expect(added.placement.sizeM == SIMD2<Double>(2.0, 2.0))
        #expect(added.placement.center == SIMD2<Double>(20.0, 10.0))
        #expect(added.openSides == OpenSideInference.defaultSide(for: added, in: layout))
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

    @Test("The canvas background starts as the default and is remembered across view models")
    func canvasBackgroundIsRemembered() throws {
        let suiteName = "canvas-background-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let first = LayoutEditorViewModel(projectID: project.id, session: session, defaults: defaults)
        #expect(first.canvasBackground == .standard)

        first.canvasBackground = .autoCAD
        let second = LayoutEditorViewModel(projectID: project.id, session: session, defaults: defaults)

        #expect(second.canvasBackground == .autoCAD)
    }

    @Test("An unknown stored canvas background falls back to the default")
    func unknownCanvasBackgroundFallsBack() throws {
        let suiteName = "canvas-background-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("neon", forKey: LayoutEditorViewModel.canvasBackgroundKey)
        let session = ProjectSession()
        let project = session.createProject(named: "Test")

        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session, defaults: defaults)

        #expect(viewModel.canvasBackground == .standard)
    }

    @Test("Focusing an issue switches layer, selects its object and centres it")
    func focusIssueSelectsAndCentres() throws {
        let context = Self.makeContext(layer: .structure)
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        let issue = LayoutIssue(severity: .warning, kind: .noOpenSides, objectIDs: [booth.id], message: "No open side")
        let viewSize = SIMD2<Double>(800, 600)

        context.viewModel.focusIssue(issue, in: viewSize)

        #expect(context.viewModel.activeLayer == .booths)
        #expect(context.viewModel.selectionID == booth.id)
        let onScreen = context.viewModel.transform.toView(booth.placement.center)
        #expect(simd_distance(onScreen, viewSize / 2.0) < 1e-6)
    }

    @Test("Focusing an issue with no objects changes nothing")
    func focusIssueWithoutObjectsIsIgnored() {
        let context = Self.makeContext(layer: .structure)
        let issue = LayoutIssue(severity: .warning, kind: .missingHallDoorEntry, objectIDs: [], message: "No entrance")
        let before = context.viewModel.transform

        context.viewModel.focusIssue(issue, in: SIMD2<Double>(800, 600))

        #expect(context.viewModel.activeLayer == .structure)
        #expect(context.viewModel.transform == before)
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
        viewModel.activeLayer = .booths

        viewModel.selectObject(booths[2].id)
        viewModel.deleteSelected()

        viewModel.selectObject(booths[0].id)
        viewModel.duplicateSelected()

        #expect(viewModel.selectedObject?.label == "B6")
    }

    @Test("Inspector edits update issues for the edited layout")
    func inspectorEditsUpdateIssues() throws {
        let context = Self.makeContext()
        let booths = context.layout.objects.filter { $0.kind == .booth }
        let boothA = try #require(booths.first)

        context.viewModel.selectObject(boothA.id)
        context.viewModel.editInspectorDraft { $0.widthM = 12.0 }

        #expect(context.viewModel.issues.contains { $0.kind == .overlappingObjects })
    }
}

extension LayoutEditorViewModelTests {
    @Test("Select booths sets selection or group and additive unions with current members")
    func selectBoothsWithoutUnsavedChanges() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Test Market")
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(10, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let boothC = LayoutObject(
            kind: .booth,
            label: "B3",
            placement: Placement(center: SIMD2<Double>(15, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(30, 30),
            objects: [boothA, boothB, boothC]
        )
        session.setDraft(ProjectDraft(name: "Test", layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.activeLayer = .booths

        viewModel.selectBooths([boothA.id])
        #expect(viewModel.selectionID == boothA.id)
        #expect(viewModel.groupSelection == nil)

        viewModel.selectBooths([boothA.id, boothB.id])
        #expect(viewModel.selectionID == nil)
        #expect(viewModel.groupMemberIDs == [boothA.id, boothB.id])

        viewModel.selectBooths([boothC.id], additive: true)
        #expect(viewModel.groupMemberIDs == [boothA.id, boothB.id, boothC.id])

        viewModel.selectBooths([])
        #expect(viewModel.selectionID == nil)
        #expect(viewModel.groupSelection == nil)
    }
}

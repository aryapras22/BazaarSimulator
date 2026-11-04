import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelLibraryTests {
    private static func makeViewModel() -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        return viewModel
    }

    @Test("Library rows contain booth templates and catalog items")
    func libraryRowsContent() {
        let viewModel = Self.makeViewModel()
        let rows = viewModel.libraryRows

        #expect(!rows.isEmpty)
        let projectRows = rows.filter { $0.category == .project }
        #expect(!projectRows.isEmpty)
        #expect(projectRows.count == 5) // Annyeong alone has 5 templates

        let catalogCount = ObjectCatalog.items.count
        let nonProjectRows = rows.filter { $0.category != .project }
        #expect(nonProjectRows.count == catalogCount)
    }

    @Test("Search query filters rows by name and keywords")
    func searchFiltersRows() {
        let viewModel = Self.makeViewModel()
        viewModel.librarySearch = "round"

        let filtered = viewModel.libraryRows
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { row in
            row.title.lowercased().contains("round") ||
            row.id.contains("round")
        })
    }

    @Test("Category filter restricts rows to chosen category")
    func categoryFiltersRows() {
        let viewModel = Self.makeViewModel()
        viewModel.libraryCategory = .furniture

        let filtered = viewModel.libraryRows
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.category == .furniture })
    }

    @Test("startPlacing selects the right placement tool")
    func startPlacingTools() throws {
        let viewModel = Self.makeViewModel()

        let templateRow = try #require(viewModel.libraryRows.first { $0.category == .project })
        viewModel.startPlacing(templateRow)
        if case .place = viewModel.tool {
            // Success
        } else {
            Issue.record("Expected .place tool, got \(viewModel.tool)")
        }

        let wallRow = try #require(viewModel.libraryRows.first { $0.id == "wall" })
        viewModel.startPlacing(wallRow)
        if case .drawWall = viewModel.tool {
            // Success
        } else {
            Issue.record("Expected .drawWall tool, got \(viewModel.tool)")
        }

        let doorRow = try #require(viewModel.libraryRows.first { $0.id == "door" })
        viewModel.startPlacing(doorRow)
        if case .placeDoor = viewModel.tool {
            // Success
        } else {
            Issue.record("Expected .placeDoor tool, got \(viewModel.tool)")
        }

        let blockedRow = try #require(viewModel.libraryRows.first { $0.id == "blocked-area" })
        viewModel.startPlacing(blockedRow)
        #expect(viewModel.tool == .blockedArea)
    }

    @Test("Template placement creates booth with size, category, inferred sides, and label N1")
    func templatePlacementCreatesBooth() throws {
        let viewModel = Self.makeViewModel()
        let templateRow = try #require(viewModel.libraryRows.first { $0.category == .project })
        viewModel.startPlacing(templateRow)

        viewModel.updatePlacementPreview(at: SIMD2<Double>(10, 10), free: false)
        let candidate = try #require(viewModel.placementPreview)
        #expect(candidate.isValid)

        let initialCount = viewModel.activeLayout?.objects.count ?? 0
        viewModel.commitPlacement(keepTool: true)

        let newCount = viewModel.activeLayout?.objects.count ?? 0
        #expect(newCount == initialCount + 1)

        let selectedID = try #require(viewModel.selectionID)
        let placedBooth = try #require(viewModel.activeLayout?.objects.first { $0.id == selectedID })
        #expect(placedBooth.label == "N1")
        #expect(placedBooth.kind == .booth)
        #expect(!placedBooth.openSides.isEmpty)

        if case .template(let template) = templateRow.source {
            #expect(placedBooth.categoryID == template.categoryID)
            #expect(placedBooth.placement.sizeM.x == template.sizeKey.shortM)
            #expect(placedBooth.placement.sizeM.y == template.sizeKey.longM)
        }

        #expect(viewModel.tool != .select)
    }

    @Test("Placing is one undo step")
    func placingIsOneUndoStep() throws {
        let viewModel = Self.makeViewModel()
        let templateRow = try #require(viewModel.libraryRows.first { $0.category == .project })
        viewModel.startPlacing(templateRow)
        viewModel.updatePlacementPreview(at: SIMD2<Double>(10, 10), free: false)

        let initialCount = viewModel.activeLayout?.objects.count ?? 0
        viewModel.commitPlacement(keepTool: true)
        #expect(viewModel.activeLayout?.objects.count == initialCount + 1)
        #expect(viewModel.canUndo)

        viewModel.undo()
        #expect(viewModel.activeLayout?.objects.count == initialCount)
    }

    @Test("Shift-click returns to select tool")
    func shiftClickReturnsToSelect() throws {
        let viewModel = Self.makeViewModel()
        let templateRow = try #require(viewModel.libraryRows.first { $0.category == .project })
        viewModel.startPlacing(templateRow)
        viewModel.updatePlacementPreview(at: SIMD2<Double>(10, 10), free: false)

        viewModel.commitPlacement(keepTool: false)
        #expect(viewModel.tool == .select)
    }

    @Test("Moving a booth leaves the booth templates unchanged")
    func movingBoothKeepsTemplates() throws {
        let viewModel = Self.makeViewModel()
        let booth = try #require(viewModel.activeLayout?.objects.first { $0.kind == .booth })
        let before = viewModel.cachedBoothTemplates

        viewModel.finishDraggingObject(id: booth.id, deltaWorld: SIMD2<Double>(2, 0))

        #expect(viewModel.cachedBoothTemplates == before)
    }

    @Test("Changing a booth's category updates the template counts")
    func changingCategoryUpdatesTemplates() throws {
        let viewModel = Self.makeViewModel()
        let booth = try #require(viewModel.activeLayout?.objects.first { $0.kind == .booth })
        let otherCategory = try #require(PreviewLayouts.sampleLegend.entries.first { $0.id != booth.categoryID })
        let before = viewModel.cachedBoothTemplates
        var recategorized = booth
        recategorized.categoryID = otherCategory.id

        viewModel.commitEdit(.replace(before: booth, after: recategorized))

        #expect(viewModel.cachedBoothTemplates != before)
    }
}

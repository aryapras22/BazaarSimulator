import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelLibraryTests {
    private static func makeViewModel(layer: EditorLayer = .booths) -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.selectLayer(layer)
        viewModel.refreshDerivedState()
        return viewModel
    }

    @Test("Library rows filter by active layer")
    func libraryRowsContent() {
        let boothsVM = Self.makeViewModel(layer: .booths)
        let boothRows = boothsVM.libraryRows
        #expect(!boothRows.isEmpty)
        #expect(boothRows.filter { $0.category == .project }.count == 1)
        #expect(boothRows.filter { $0.category == .furniture }.map(\.id) == ["table-rect-4"])
        #expect(boothRows.allSatisfy { $0.category.layer == .booths })

        let structureVM = Self.makeViewModel(layer: .structure)
        let structureRows = structureVM.libraryRows
        #expect(!structureRows.isEmpty)
        #expect(!structureRows.contains { $0.category == .project })
        #expect(structureRows.allSatisfy { $0.category.layer == .structure })
        #expect(structureRows.contains { $0.id == "wall" })
        #expect(structureRows.contains { $0.id == "door" })
        #expect(structureRows.contains { $0.id == "block" })
    }

    @Test("Search query filters rows by name and keywords")
    func searchFiltersRows() {
        let viewModel = Self.makeViewModel(layer: .structure)
        viewModel.librarySearch = "door"

        let filtered = viewModel.libraryRows
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { row in
            row.title.lowercased().contains("door") ||
            row.id.contains("door")
        })
    }

    @Test("startPlacing selects the right placement tool")
    func startPlacingTools() throws {
        let boothsVM = Self.makeViewModel(layer: .booths)
        let templateRow = try #require(boothsVM.libraryRows.first { $0.category == .project })
        boothsVM.startPlacing(templateRow)
        if case .place = boothsVM.tool {
            // Success
        } else {
            Issue.record("Expected .place tool, got \(boothsVM.tool)")
        }

        let structureVM = Self.makeViewModel(layer: .structure)
        let wallRow = try #require(structureVM.libraryRows.first { $0.id == "wall" })
        structureVM.startPlacing(wallRow)
        if case .drawWall = structureVM.tool {
            // Success
        } else {
            Issue.record("Expected .drawWall tool, got \(structureVM.tool)")
        }

        let doorRow = try #require(structureVM.libraryRows.first { $0.id == "door" })
        structureVM.startPlacing(doorRow)
        if case .placeDoor = structureVM.tool {
            // Success
        } else {
            Issue.record("Expected .placeDoor tool, got \(structureVM.tool)")
        }

        let blockedRow = try #require(structureVM.libraryRows.first { $0.id == "blocked-area" })
        structureVM.startPlacing(blockedRow)
        #expect(structureVM.tool == .blockedArea)
    }

    @Test("ToolRailItem filters items by active layer")
    func toolRailItemsByLayer() {
        #expect(ToolRailItem.items(for: .structure) == [.select, .wall, .room, .library])
        #expect(ToolRailItem.items(for: .booths) == [.select, .row, .fill, .library])
    }

    @Test("CatalogCategory maps to its layer")
    func catalogCategoryLayers() {
        #expect(CatalogCategory.structure.layer == .structure)
        #expect(CatalogCategory.project.layer == .booths)
        #expect(CatalogCategory.furniture.layer == .booths)
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
}

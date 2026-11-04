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
}

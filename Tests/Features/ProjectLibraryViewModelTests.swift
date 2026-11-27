import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ProjectLibraryViewModelTests")
struct ProjectLibraryViewModelTests {
    @Test("New projects are named Untitled, Untitled 2, and so on")
    @MainActor
    func newProjectsAreNumberedIncrementally() {
        let session = ProjectSession()
        let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })

        viewModel.createProject()
        #expect(session.projects.count == 1)
        #expect(session.projects[0].name == "Untitled")

        viewModel.createProject()
        #expect(session.projects.count == 2)
        #expect(session.projects[1].name == "Untitled 2")

        viewModel.createProject()
        #expect(session.projects.count == 3)
        #expect(session.projects[2].name == "Untitled 3")
    }

    @Test("A freed number is reused")
    @MainActor
    func freedNumberIsReused() {
        let session = ProjectSession()
        let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })

        viewModel.createProject()
        viewModel.createProject()
        viewModel.createProject()

        let secondID = session.projects[1].id
        session.renameProject(id: secondID, to: "Renamed")

        viewModel.createProject()
        #expect(session.projects.last?.name == "Untitled 2")
    }

    @Test("Search filters by name, case-insensitive")
    @MainActor
    func searchFiltersCaseInsensitive() {
        let session = ProjectSession()
        let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })

        session.createProject(named: "Summer Bazaar")
        session.createProject(named: "Winter Fair")
        session.createProject(named: "Spring Market")

        viewModel.searchText = "bazaar"
        #expect(viewModel.filteredProjects.count == 1)
        #expect(viewModel.filteredProjects[0].name == "Summer Bazaar")

        viewModel.searchText = "FAIR"
        #expect(viewModel.filteredProjects.count == 1)
        #expect(viewModel.filteredProjects[0].name == "Winter Fair")

        viewModel.searchText = "market"
        #expect(viewModel.filteredProjects.count == 1)
        #expect(viewModel.filteredProjects[0].name == "Spring Market")

        viewModel.searchText = ""
        #expect(viewModel.filteredProjects.count == 3)
    }

    @Test("Renaming through the session updates the row")
    @MainActor
    func renamingThroughSessionUpdatesRow() {
        let session = ProjectSession()
        let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })

        viewModel.createProject()
        guard let createdID = session.projects.first?.id else {
            Issue.record("Expected created project")
            return
        }

        session.renameProject(id: createdID, to: "Grand Bazaar")
        #expect(viewModel.filteredProjects.first?.name == "Grand Bazaar")
    }

    @Test("Selecting a project selects it in session and invokes onOpenProject")
    @MainActor
    func selectProjectInvokesCallback() {
        let session = ProjectSession()
        var openedID: UUID?
        let viewModel = ProjectLibraryViewModel(session: session, onOpenProject: { openedID = $0 })
        let project = session.createProject(named: "Bazaar 1")

        viewModel.selectProject(project)
        #expect(session.activeProjectID == project.id)
        #expect(openedID == project.id)
    }

    private func parameters(visitors: Int) -> EventParameters {
        var copy = TestLayouts.parameters
        copy.totalVisitors = visitors
        return copy
    }

    private func analysis(for layout: Layout) -> LayoutAnalysis {
        let spot = SpotMeasurement(
            number: 1, name: "Near B1", position: SIMD2(4, 5),
            densitySamples: [0.25, 0.5], peopleSamples: [2, 5]
        )
        var measured = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 60, spots: [spot],
            flowPerMinute: [2, 3], simulatedPeople: 40, totalPeople: 40
        )
        measured.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        return measured
    }

    @Test("Sidebar highlights the earlier matched run on the latest analysis page instead of always the newest run")
    @MainActor
    func isAnalysisSelectedHighlightsMatchedEarlierRun() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let analyses = layouts.map(analysis(for:))
        let viewModel = ProjectLibraryViewModel(
            session: session, destination: { .analysis(projectID: project.id) }, onOpenProject: { _ in }
        )

        let run1 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        ))
        let run2 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 600), peakMinute: 690, in: project.id
        ))

        let duplicate = session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        )

        #expect(duplicate == nil)
        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))
    }

    @Test("Deleting the displayed earlier run falls back to highlighting the newest run in the sidebar")
    @MainActor
    func deletingDisplayedEarlierRunFallsBackToHighlightingNewestRun() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let analyses = layouts.map(analysis(for:))
        let viewModel = ProjectLibraryViewModel(
            session: session, destination: { .analysis(projectID: project.id) }, onOpenProject: { _ in }
        )

        let run1 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        ))
        let run2 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 600), peakMinute: 690, in: project.id
        ))
        _ = session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        )

        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))

        viewModel.deleteAnalysis(run1, in: project)

        #expect(viewModel.isAnalysisSelected(run2, in: project))
    }
}

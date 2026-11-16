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

    @Test("Result tabs stack per project and only show for the selected project")
    @MainActor
    func resultTabsStackPerProject() {
        let session = ProjectSession()
        var openedTab: SimulationResultTab?
        let viewModel = ProjectLibraryViewModel(
            session: session,
            onOpenProject: { _ in },
            onOpenResult: { openedTab = $0 }
        )
        let first = session.createProject(named: "Bazaar 1")
        let second = session.createProject(named: "Bazaar 2")

        var params1 = TestLayouts.parameters
        params1.totalVisitors = 500
        var params2 = TestLayouts.parameters
        params2.totalVisitors = 1200

        session.selectProject(id: first.id)
        let tab1 = session.addResultTab(for: first.id, parameters: params1)
        let tab2 = session.addResultTab(for: first.id, parameters: params2)

        #expect(viewModel.resultTabs.map(\.title) == ["Result 1", "Result 2"])
        #expect(viewModel.selectedResultTabID == tab2.id)

        // Switching to second project shows its own empty result list
        viewModel.selectProject(second)
        #expect(viewModel.resultTabs.isEmpty)

        // Switching back to first project and selecting Result 1 restores its parameters
        viewModel.selectProject(first)
        #expect(viewModel.selectedResultTabID == nil)
        viewModel.selectResultTab(tab1)
        #expect(viewModel.selectedResultTabID == tab1.id)
        #expect(session.eventParameters(for: first.id)?.totalVisitors == 500)
        #expect(openedTab == tab1)
    }
}

import Testing
@testable import BazaarSimulator

@Suite("ProjectLibraryViewModelTests")
struct ProjectLibraryViewModelTests {
    @Test("New projects are numbered Bazaar 1, Bazaar 2, and so on")
    @MainActor
    func newProjectsAreNumberedIncrementally() {
        let session = ProjectSession()
        let router = AppRouter()
        let viewModel = ProjectLibraryViewModel(session: session, router: router)

        viewModel.createProject()
        #expect(session.projects.count == 1)
        #expect(session.projects[0].name == "Bazaar 1")

        viewModel.createProject()
        #expect(session.projects.count == 2)
        #expect(session.projects[1].name == "Bazaar 2")

        viewModel.createProject()
        #expect(session.projects.count == 3)
        #expect(session.projects[2].name == "Bazaar 3")
    }

    @Test("A freed number is reused")
    @MainActor
    func freedNumberIsReused() {
        let session = ProjectSession()
        let router = AppRouter()
        let viewModel = ProjectLibraryViewModel(session: session, router: router)

        viewModel.createProject()
        viewModel.createProject()
        viewModel.createProject()

        let secondID = session.projects[1].id
        session.renameProject(id: secondID, to: "Renamed")

        viewModel.createProject()
        #expect(session.projects.last?.name == "Bazaar 2")
    }

    @Test("Search filters by name, case-insensitive")
    @MainActor
    func searchFiltersCaseInsensitive() {
        let session = ProjectSession()
        let router = AppRouter()
        let viewModel = ProjectLibraryViewModel(session: session, router: router)

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
        let router = AppRouter()
        let viewModel = ProjectLibraryViewModel(session: session, router: router)

        viewModel.createProject()
        guard let createdID = session.projects.first?.id else {
            Issue.record("Expected created project")
            return
        }

        session.renameProject(id: createdID, to: "Grand Bazaar")
        #expect(viewModel.filteredProjects.first?.name == "Grand Bazaar")
    }
}

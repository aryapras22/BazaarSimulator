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
        #expect(viewModel.projects.count == 1)
        #expect(viewModel.projects[0].name == "Bazaar 1")

        viewModel.createProject()
        #expect(viewModel.projects.count == 2)
        #expect(viewModel.projects[1].name == "Bazaar 2")

        viewModel.createProject()
        #expect(viewModel.projects.count == 3)
        #expect(viewModel.projects[2].name == "Bazaar 3")
    }

    @Test("Search filters by name, case-insensitive")
    @MainActor
    func searchFiltersCaseInsensitive() {
        let session = ProjectSession()
        let router = AppRouter()
        let viewModel = ProjectLibraryViewModel(session: session, router: router)

        viewModel.projects = [
            ProjectItem(name: "Summer Bazaar"),
            ProjectItem(name: "Winter Fair"),
            ProjectItem(name: "Spring Market")
        ]

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
        #expect(viewModel.projects[0].name == "Bazaar 1")

        session.projectName = "Grand Bazaar"
        #expect(viewModel.projects[0].name == "Grand Bazaar")
    }
}

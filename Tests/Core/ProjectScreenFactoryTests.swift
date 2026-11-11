import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ProjectScreenFactoryTests")
@MainActor
struct ProjectScreenFactoryTests {
    @Test("makeSetupViewModel(projectID:) returns the same instance on second call with the same ID")
    func returnsSameInstanceForSameID() {
        let services = AppServices()
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: services, router: router)
        let id = UUID()

        let first = factory.makeSetupViewModel(projectID: id)
        let second = factory.makeSetupViewModel(projectID: id)

        #expect(first === second)
    }

    @Test("makeSetupViewModel(projectID:) returns a new instance for a different ID")
    func returnsDifferentInstanceForDifferentID() {
        let services = AppServices()
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: services, router: router)
        let id1 = UUID()
        let id2 = UUID()

        let first = factory.makeSetupViewModel(projectID: id1)
        let second = factory.makeSetupViewModel(projectID: id2)

        #expect(first !== second)
    }

    @Test("makeLayoutEditorViewModel(projectID:) caches per project ID")
    func cachesLayoutEditorViewModelPerProjectID() {
        let services = AppServices()
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: services, router: router)
        let id1 = UUID()
        let id2 = UUID()

        let first = factory.makeLayoutEditorViewModel(projectID: id1)
        let second = factory.makeLayoutEditorViewModel(projectID: id1)
        let other = factory.makeLayoutEditorViewModel(projectID: id2)

        #expect(first === second)
        #expect(first !== other)
    }

    @Test("AppServices starts empty by default")
    func appServicesStartsEmptyByDefault() {
        let services = AppServices()

        #expect(services.projectSession.projects.isEmpty)
        #expect(services.initialDestination == .empty)
    }

    @Test("AppServices seeds a mock project when asked")
    func appServicesSeedsMockProjectWhenAsked() throws {
        let services = AppServices(seedsMockProject: true)
        let activeID = try #require(services.projectSession.activeProjectID)
        let draft = try #require(services.projectSession.draft(for: activeID))

        #expect(services.projectSession.projects.count == 2)
        #expect(services.initialDestination == .setup(projectID: activeID))
        #expect(draft.layouts.count == 2)
        #expect(!draft.layouts[0].objects.isEmpty)
        #expect(!draft.layouts[1].objects.isEmpty)
        #expect(services.importQueue.legend(for: activeID) != nil)
        #expect(services.importQueue.files(for: activeID).filter { $0.kind == .floorPlan }.count == 2)

        let moreMarket = try #require(services.projectSession.projects.first { $0.name == "More Market" })
        let moreMarketDraft = try #require(services.projectSession.draft(for: moreMarket.id))
        #expect(moreMarketDraft.layouts.count == 7)
        #expect(moreMarketDraft.layouts.allSatisfy { !$0.objects.isEmpty })
    }

    @Test("Selecting project routes to setup when no layouts exist")
    func selectingProjectWithoutLayoutsRoutesToSetup() {
        let services = AppServices()
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: services, router: router)
        let libraryVM = factory.makeLibraryViewModel()

        libraryVM.createProject()
        guard let project = services.projectSession.projects.first else {
            Issue.record("Expected created project")
            return
        }

        #expect(router.destination == .setup(projectID: project.id))

        let setupVM = factory.makeSetupViewModel(projectID: project.id)
        #expect(setupVM.projectName == "Bazaar 1")
        _ = setupVM.statusText
        _ = setupVM.legendEntries
        _ = setupVM.planRows
        _ = setupVM.floorPlanFiles

        let view = ProjectSetupView(viewModel: setupVM)
        _ = view.body
    }

    @Test("ProjectSetupView with seeded mock project")
    func projectSetupViewWithSeededMockProject() {
        let services = AppServices(seedsMockProject: true)
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: services, router: router)
        let activeID = services.projectSession.activeProjectID!

        let setupVM = factory.makeSetupViewModel(projectID: activeID)
        let view = ProjectSetupView(viewModel: setupVM)
        _ = view.body
    }
}

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

        #expect(services.projectSession.projects.count == 1)
        #expect(services.initialDestination == .review(projectID: activeID))
        #expect(draft.layouts.count == 2)
        #expect(!draft.layouts[0].objects.isEmpty)
        #expect(!draft.layouts[1].objects.isEmpty)
    }
}

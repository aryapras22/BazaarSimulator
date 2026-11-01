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
}

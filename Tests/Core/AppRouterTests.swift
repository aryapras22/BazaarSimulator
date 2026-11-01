import Foundation
import Testing
@testable import BazaarSimulator

@Suite("AppRouterTests")
@MainActor
struct AppRouterTests {
    @Test("No project selected shows the empty workspace")
    func noProjectSelectedShowsEmpty() {
        let router = AppRouter()
        #expect(router.destination == .empty)
    }

    @Test("A project shows setup with projectID")
    func projectShowsSetup() {
        let router = AppRouter()
        let id = UUID()
        router.showSetup(projectID: id)
        #expect(router.destination == .setup(projectID: id))
    }

    @Test("Continue shows review with projectID")
    func continueShowsReview() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showReview(projectID: id)
        #expect(router.destination == .review(projectID: id))
    }

    @Test("Show empty resets destination to empty")
    func showEmptyResetsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showEmpty()
        #expect(router.destination == .empty)
    }
}

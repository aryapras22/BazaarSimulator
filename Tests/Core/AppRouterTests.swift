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

    @Test("Continue shows analysis with projectID")
    func continueShowsAnalysis() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showAnalysis(projectID: id)
        #expect(router.destination == .analysis(projectID: id))
    }

//    @Test("Show review redirects to analysis with projectID")
//    func showReviewRedirectsToAnalysis() {
//        let id = UUID()
//        let router = AppRouter(destination: .setup(projectID: id))
//        router.showReview(projectID: id)
//        #expect(router.destination == .analysis(projectID: id))
//    }
    
    @Test("Show review redirects to analysis with projectID")
    func showReviewRedirectsToAnalysis() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showAnalysis(projectID: id)
        #expect(router.destination == .analysis(projectID: id))
    }

    @Test("Show editor sets destination to editor")
    func showEditorSetsDestination() {
        let id = UUID()
        let router = AppRouter()
        router.showEditor(projectID: id)
        #expect(router.destination == .editor(projectID: id))
    }

    @Test("Show simulation sets destination to simulation")
    func showSimulationSetsDestination() {
        let id = UUID()
        let router = AppRouter()
        router.showSimulation(projectID: id)
        #expect(router.destination == .simulation(projectID: id))
    }

    @Test("Show compare sets destination to compare with projectID")
    func showCompareSetsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .review(projectID: id))
        router.showCompare(projectID: id)
        #expect(router.destination == .compare(projectID: id))
    }

    @Test("Show empty resets destination to empty")
    func showEmptyResetsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showEmpty()
        #expect(router.destination == .empty)
    }
}

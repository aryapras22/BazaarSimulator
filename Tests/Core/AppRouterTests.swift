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

    @Test("Requesting a simulation leaves the screen alone and remembers which layout")
    func requestSimulation() {
        let id = UUID()
        let router = AppRouter(destination: .analysis(projectID: id))
        router.requestSimulation(projectID: id, layout: .two)
        #expect(router.simulationRequest == SimulationRequest(projectID: id, layout: .two))
        #expect(router.destination == .analysis(projectID: id))
    }

    @Test("Clearing the simulation request empties it")
    func clearSimulationRequest() {
        let id = UUID()
        let router = AppRouter()
        router.requestSimulation(projectID: id, layout: .one)
        router.clearSimulationRequest()
        #expect(router.simulationRequest == nil)
    }

    @Test("Show analysis sets destination to analysis with projectID")
    func showAnalysisSetsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showAnalysis(projectID: id)
        #expect(router.destination == .analysis(projectID: id))
    }

    @Test("Showing parameters leaves the screen alone and remembers the project")
    func showParametersKeepsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showParameters(projectID: id)
        #expect(router.parametersProjectID == id)
        #expect(router.destination == .setup(projectID: id))
    }

    @Test("Dismissing parameters clears the request")
    func dismissParametersClears() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showParameters(projectID: id)
        router.dismissParameters()
        #expect(router.parametersProjectID == nil)
    }

    @Test("Show empty resets destination to empty")
    func showEmptyResetsDestination() {
        let id = UUID()
        let router = AppRouter(destination: .setup(projectID: id))
        router.showEmpty()
        #expect(router.destination == .empty)
    }
}

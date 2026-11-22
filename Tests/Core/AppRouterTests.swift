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

    @Test("Showing a simulation opens the simulation page and Back returns to analysis")
    func showAndCloseSimulationFromAnalysis() {
        let id = UUID()
        let router = AppRouter(destination: .analysis(projectID: id))
        router.showSimulation(projectID: id, layout: .two)
        #expect(router.destination == .simulation(projectID: id, layout: .two, analysisID: nil))

        router.closeSimulation(projectID: id)
        #expect(router.destination == .analysis(projectID: id))
    }

    @Test("Showing a simulation for a saved run returns to that saved run on Back")
    func showAndCloseSimulationFromSavedRun() {
        let id = UUID(), run = UUID()
        let router = AppRouter(destination: .savedAnalysis(projectID: id, analysisID: run))
        router.showSimulation(projectID: id, layout: .one, analysisID: run)
        #expect(router.destination == .simulation(projectID: id, layout: .one, analysisID: run))

        router.closeSimulation(projectID: id, analysisID: run)
        #expect(router.destination == .savedAnalysis(projectID: id, analysisID: run))
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

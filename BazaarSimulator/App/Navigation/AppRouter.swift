import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup(projectID: UUID)
    case review(projectID: UUID)
    case analysis(projectID: UUID)
    case editor(projectID: UUID)
}

/// A request to open the simulator for one layout of a project, in its own window.
struct SimulationRequest: Codable, Hashable, Sendable {
    let projectID: UUID
    let layout: LayoutID
}

@Observable
@MainActor
final class AppRouter {
    var destination: AppDestination
    /// The project whose Parameters sheet is showing. Set when setup continues, so the parameters are
    /// chosen before the analysis opens.
    private(set) var parametersProjectID: UUID?
    /// Set when a layout's simulator should open. The window opens and clears it.
    private(set) var simulationRequest: SimulationRequest?

    init(destination: AppDestination = .empty) {
        self.destination = destination
    }

    func showEmpty() {
        destination = .empty
    }

    func showSetup(projectID: UUID) {
        destination = .setup(projectID: projectID)
    }

//    func showReview(projectID: UUID) {
//        destination = .analysis(projectID: projectID)
//    }

    func showAnalysis(projectID: UUID) {
        destination = .analysis(projectID: projectID)
    }

    func showEditor(projectID: UUID) {
        destination = .editor(projectID: projectID)
    }

    func requestSimulation(projectID: UUID, layout: LayoutID) {
        simulationRequest = SimulationRequest(projectID: projectID, layout: layout)
    }

    func clearSimulationRequest() {
        simulationRequest = nil
    }

    func showParameters(projectID: UUID) {
        parametersProjectID = projectID
    }

    func dismissParameters() {
        parametersProjectID = nil
    }
}

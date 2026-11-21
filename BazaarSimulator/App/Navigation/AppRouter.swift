import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup(projectID: UUID)
    case review(projectID: UUID)
    case analysis(projectID: UUID)
    case editor(projectID: UUID)
    case savedAnalysis(projectID: UUID, analysisID: UUID)
}

extension AppDestination {
    /// The project the screen belongs to. Nil for the empty workspace.
    var projectID: UUID? {
        switch self {
        case .empty: nil
        case .setup(let id), .review(let id), .analysis(let id), .editor(let id): id
        case .savedAnalysis(let id, _): id
        }
    }
}

/// A request to open the simulator for one layout of a project, in its own window.
struct SimulationRequest: Codable, Hashable, Sendable {
    let projectID: UUID
    let layout: LayoutID
    /// The saved run to play. Nil plays the project's layouts as they are now.
    var analysisID: UUID?
}

@Observable
@MainActor
final class AppRouter {
    var destination: AppDestination
    /// The project whose Parameters overlay is showing.
    private(set) var parametersProjectID: UUID?
    /// When Parameters was opened from a saved run, the run whose stored values seed the form.
    private(set) var parametersAnalysisID: UUID?
    /// Set when a layout's simulator should open. The window opens and clears it.
    private(set) var simulationRequest: SimulationRequest?
    private var editorOrigin: AppDestination?

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

    func showSavedAnalysis(projectID: UUID, analysisID: UUID) {
        destination = .savedAnalysis(projectID: projectID, analysisID: analysisID)
    }

    /// Opens the editor and remembers the page it was opened from, so Back returns there.
    func showEditor(projectID: UUID) {
        switch destination {
        case .setup(let id) where id == projectID, .analysis(let id) where id == projectID:
            editorOrigin = destination
        default:
            break
        }
        destination = .editor(projectID: projectID)
    }

    /// Leaves the editor for the page it was opened from, or for the analysis when it is not known.
    func closeEditor(projectID: UUID) {
        if let origin = editorOrigin, origin.projectID == projectID {
            destination = origin
        } else {
            destination = .analysis(projectID: projectID)
        }
        editorOrigin = nil
    }

    func requestSimulation(projectID: UUID, layout: LayoutID, analysisID: UUID? = nil) {
        simulationRequest = SimulationRequest(projectID: projectID, layout: layout, analysisID: analysisID)
    }

    func clearSimulationRequest() {
        simulationRequest = nil
    }

    func showParameters(projectID: UUID, analysisID: UUID? = nil) {
        parametersProjectID = projectID
        parametersAnalysisID = analysisID
    }

    func dismissParameters() {
        parametersProjectID = nil
        parametersAnalysisID = nil
    }
}

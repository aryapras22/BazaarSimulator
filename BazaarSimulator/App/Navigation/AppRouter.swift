import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup(projectID: UUID)
    case review(projectID: UUID)
    case analysis(projectID: UUID)
    case editor(projectID: UUID)
    case savedAnalysis(projectID: UUID, analysisID: UUID)
    case simulation(projectID: UUID, layout: LayoutID, analysisID: UUID?)
}

extension AppDestination {
    /// The project the screen belongs to. Nil for the empty workspace.
    var projectID: UUID? {
        switch self {
        case .empty: nil
        case .setup(let id), .review(let id), .analysis(let id), .editor(let id): id
        case .savedAnalysis(let id, _), .simulation(let id, _, _): id
        }
    }
}

@Observable
@MainActor
final class AppRouter {
    var destination: AppDestination
    /// The project whose Parameters overlay is showing.
    private(set) var parametersProjectID: UUID?
    /// When Parameters was opened from a saved run, the run whose stored values seed the form.
    private(set) var parametersAnalysisID: UUID?
    private var editorOrigin: AppDestination?
    private var simulationOrigin: AppDestination?
    /// The two layouts the simulation page plays, when they are not the ones the run or the live pair names: a saved run
    /// showing another pair than the one it was made with. Nil otherwise.
    private(set) var simulationLayoutIDs: [UUID]?

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

    /// Opens the simulation replay page and remembers where it was opened from, so Back returns there.
    func showSimulation(projectID: UUID, layout: LayoutID, analysisID: UUID? = nil, layouts: [UUID]? = nil) {
        simulationLayoutIDs = layouts
        if destination.projectID == projectID {
            simulationOrigin = destination
        }
        destination = .simulation(projectID: projectID, layout: layout, analysisID: analysisID)
    }

    /// Leaves the simulation replay page for the page it was opened from.
    func closeSimulation(projectID: UUID, analysisID: UUID? = nil) {
        if let origin = simulationOrigin, origin.projectID == projectID {
            destination = origin
        } else if let analysisID {
            destination = .savedAnalysis(projectID: projectID, analysisID: analysisID)
        } else {
            destination = .analysis(projectID: projectID)
        }
        simulationOrigin = nil
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

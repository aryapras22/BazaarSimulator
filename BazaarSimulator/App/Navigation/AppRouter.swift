import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup(projectID: UUID)
    case review(projectID: UUID)
    case analysis(projectID: UUID)
    case editor(projectID: UUID)
    case simulation(projectID: UUID)
}

@Observable
@MainActor
final class AppRouter {
    var destination: AppDestination

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

    func showSimulation(projectID: UUID) {
        destination = .simulation(projectID: projectID)
    }
}

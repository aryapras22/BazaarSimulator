import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup(projectID: UUID)
    case review(projectID: UUID)
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

    func showReview(projectID: UUID) {
        destination = .review(projectID: projectID)
    }
}

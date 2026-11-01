import Foundation
import Observation

enum AppDestination: Equatable, Sendable {
    case empty
    case setup
    case reviewPlaceholder
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

    func showSetup() {
        destination = .setup
    }

    func showReviewPlaceholder() {
        destination = .reviewPlaceholder
    }
}

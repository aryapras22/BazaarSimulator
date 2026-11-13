import Foundation

struct ImportLogEntry: Identifiable, Sendable, Hashable {
    enum Severity: Sendable, Hashable {
        case info
        case failure
    }

    let id = UUID()
    let date: Date
    let projectID: UUID
    let fileName: String
    let message: String
    let severity: Severity
}

enum DevMode {
    static let defaultsKey = "devMode"
}

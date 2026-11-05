import Foundation

/// A kind of visitor. Behavior parameters for the engine are added when the engine reads them.
struct VisitorType: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
}

import Foundation

/// A bundled starting point: a mix (percent per visitor type id).
struct BazaarTypePreset: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let mix: [String: Int]
}

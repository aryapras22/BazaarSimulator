import Foundation

/// A bundled starting point: a visitor total and a mix (percent per visitor type id).
struct BazaarTypePreset: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let totalVisitors: Int
    let mix: [String: Int]
}

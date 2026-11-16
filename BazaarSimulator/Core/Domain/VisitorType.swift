import Foundation

/// A kind of visitor and the behavior parameters the simulation reads.
struct VisitorType: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    /// How fast the visitor walks when nothing is in the way.
    var walkingSpeedMps: Double = 1.2
    /// How many booths the visitor plans to stop at.
    var plannedStops: Int = 4
    /// How long the visitor stays at each booth.
    var dwellMinutes: Double = 2
}

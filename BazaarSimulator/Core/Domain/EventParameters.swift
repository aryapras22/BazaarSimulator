import Foundation

/// Who visits and when. Shared by every layout in a project.
struct EventParameters: Codable, Sendable, Hashable {
    static let customBazaarTypeID = "custom"
    static let customBazaarTypeName = "Custom"

    var totalVisitors: Int
    var eventHours: TimeRange
    var peakPeriods: [TimeRange] = []
    var bazaarTypeID: String
    var mix: VisitorMix
}

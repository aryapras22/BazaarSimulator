import Foundation

/// Who visits and when. Shared by every layout in a project.
struct EventParameters: Codable, Sendable, Equatable {
    var totalVisitors: Int
    var eventHours: TimeRange
    var peakPeriods: [TimeRange] = []
    var bazaarTypeID: String
    var mix: VisitorMix
    var groupSize: Int
}

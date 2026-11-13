import Foundation

/// Everything one run needs.
struct SimulationInput: Sendable, Hashable {
    var layout: Layout
    var parameters: EventParameters
    var visitorTypes: [VisitorType]
    /// Tells food booths from the rest.
    var legend = Legend()
    var seed: UInt64 = 42
    /// The stretch of the day the monitored spots are picked for (the busiest window).
    /// Without one, spots are picked from the whole day.
    var focus: TimeRange?
}

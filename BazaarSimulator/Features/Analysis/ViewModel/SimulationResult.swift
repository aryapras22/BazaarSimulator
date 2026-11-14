import Foundation

/// The two layouts' outcomes and playback, ready for the compare page and the simulator.
struct SimulationResult: Sendable {
    let outcomes: [LayoutID: LayoutOutcome]
    let layouts: [LayoutID: Layout]
    let analyses: [LayoutID: LayoutAnalysis]
    let visitorTypes: [VisitorType]
    let schedule: DaySchedule

    var peakHourText: String { schedule.peakText }
    var windowMinutes: Double { schedule.windowMinutes }
    var sampleHours: [Double] { schedule.sampleHours }

    func replay(for layout: LayoutID) -> SimulationReplay? {
        analyses[layout]?.replay
    }
}

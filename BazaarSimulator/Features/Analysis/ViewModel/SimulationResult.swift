import Foundation

/// The two layouts' outcomes and playback, ready for the compare page and the simulator.
struct SimulationResult: Sendable {
    let outcomes: [LayoutID: LayoutOutcome]
    let layouts: [LayoutID: Layout]
    let analyses: [LayoutID: LayoutAnalysis]
    let visitorTypes: [VisitorType]
    let schedule: DaySchedule
    /// The best of all the project's layouts, when the run covered them all. Nil for a saved run, which has only its
    /// own.
    var bestProjectLayoutID: Layout.ID?
    /// How every layout of the project did, the two on the page and the others, when the run covered them all.
    var projectOutcomes: [ProjectOutcome] = []
    /// Every layout of the project simulated together, which lets the cards switch layouts without simulating again.
    var projectRun: ProjectRun?

    var peakHourText: String { schedule.peakText }
    var windowMinutes: Double { schedule.windowMinutes }
    var sampleHours: [Double] { schedule.sampleHours }

    func replay(for layout: LayoutID) -> SimulationReplay? {
        analyses[layout]?.replay
    }
}

import Foundation

extension SimulationResult {
    /// The page for a saved analysis: its first one or two layouts, read from the stored measurements.
    /// Nil when it has none. It carries no replay: a simulator makes its own from the project's layouts.
    init?(saved: SavedAnalysis, visitorTypes: [VisitorType], projectLayouts: [Layout] = []) {
        let count = min(saved.layouts.count, saved.analyses.count, LayoutID.allCases.count)
        guard count >= 1 else { return nil }
        let schedule = DaySchedule(parameters: saved.parameters, peakMinute: saved.peakMinute)
        var outcomes: [LayoutID: LayoutOutcome] = [:]
        var layouts: [LayoutID: Layout] = [:]
        var analyses: [LayoutID: LayoutAnalysis] = [:]
        for (index, id) in LayoutID.allCases.prefix(count).enumerated() {
            let name = LayoutNames.name(of: saved.layouts[index], in: projectLayouts, place: id)
            outcomes[id] = OutcomeBuilder.build(
                layoutID: id, name: name, analysis: saved.analyses[index], schedule: schedule
            )
            layouts[id] = saved.layouts[index]
            analyses[id] = saved.analyses[index]
        }
        self.init(
            outcomes: outcomes, layouts: layouts, analyses: analyses, visitorTypes: visitorTypes, schedule: schedule
        )
    }
}

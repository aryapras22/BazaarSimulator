import Foundation

/// The two layouts' outcomes, ready for the compare page.
struct CompareResult: Sendable {
    let outcomes: [LayoutID: LayoutOutcome]
    let layouts: [LayoutID: Layout]
    let analyses: [LayoutID: LayoutAnalysis]
    let schedule: DaySchedule

    var peakHourText: String { schedule.peakText }
    var windowMinutes: Double { schedule.windowMinutes }
    var sampleHours: [Double] { schedule.sampleHours }

    /// Compares two layouts of a saved analysis, the first two unless `indices` picks others. Nil when it has fewer
    /// than two, or when an index is out of range.
    init?(analysis: SavedAnalysis, indices: [LayoutID: Int]? = nil) {
        let chosen = indices ?? Dictionary(uniqueKeysWithValues: LayoutID.allCases.enumerated().map { ($1, $0) })
        guard analysis.layouts.count >= LayoutID.allCases.count,
              analysis.measurements.count == analysis.layouts.count,
              chosen.count == LayoutID.allCases.count,
              chosen.values.allSatisfy({ analysis.layouts.indices.contains($0) })
        else { return nil }
        let pairs = LayoutID.allCases.compactMap { id in
            chosen[id].map { (id: id, layout: analysis.layouts[$0], measurements: analysis.measurements[$0]) }
        }

        let schedule = DaySchedule(parameters: analysis.parameters, peakMinute: analysis.peakMinute)
        var outcomes: [LayoutID: LayoutOutcome] = [:]
        var layouts: [LayoutID: Layout] = [:]
        var analyses: [LayoutID: LayoutAnalysis] = [:]
        for pair in pairs {
            outcomes[pair.id] = OutcomeBuilder.build(layoutID: pair.id, analysis: pair.measurements, schedule: schedule)
            layouts[pair.id] = pair.layout
            analyses[pair.id] = pair.measurements
        }
        self.outcomes = outcomes
        self.layouts = layouts
        self.analyses = analyses
        self.schedule = schedule
    }
}

import Foundation

/// Every layout of a project simulated in one go, with one busiest window for all of them. Any two of its layouts can
/// be put on the cards from it at once, so switching a card never simulates again.
struct ProjectRun: Sendable {
    /// The project's layouts, in the order that numbers them, as they were when the run was made.
    let layouts: [Layout]
    let analyses: [Layout.ID: LayoutAnalysis]
    /// How each layout did, named as the project numbers it, in the project's order.
    let outcomes: [ProjectOutcome]
    let bestLayoutID: Layout.ID?
    let schedule: DaySchedule
    let parameters: EventParameters
    let visitorTypes: [VisitorType]

    /// The run still describes the project: nothing it was made from has changed.
    func isCurrent(parameters: EventParameters, layouts: [Layout]) -> Bool {
        self.parameters == parameters && self.layouts == layouts
    }

    /// The page for two of the layouts, or one. Nil when the run does not hold them all.
    func result(showing pair: [Layout]) -> SimulationResult? {
        guard !pair.isEmpty else { return nil }
        var outcomesByPlace: [LayoutID: LayoutOutcome] = [:]
        var layoutsByPlace: [LayoutID: Layout] = [:]
        var analysesByPlace: [LayoutID: LayoutAnalysis] = [:]
        for (place, layout) in zip(LayoutID.allCases, pair) {
            guard let analysis = analyses[layout.id],
                  let outcome = outcomes.first(where: { $0.layoutID == layout.id })?.outcome
            else { return nil }
            outcomesByPlace[place] = outcome.placed(at: place)
            layoutsByPlace[place] = layout
            analysesByPlace[place] = analysis
        }
        var result = SimulationResult(
            outcomes: outcomesByPlace,
            layouts: layoutsByPlace,
            analyses: analysesByPlace,
            visitorTypes: visitorTypes,
            schedule: schedule
        )
        result.projectOutcomes = outcomes
        result.bestProjectLayoutID = bestLayoutID
        result.projectRun = self
        return result
    }
}

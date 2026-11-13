import Foundation

/// Runs (or reads from the cache) the simulation for a project's first two layouts, using the
/// project's parameters. Anything the project has not set falls back to the simulator's defaults.
@MainActor
enum SimulationLoader {
    enum Result {
        case needsLayouts(count: Int)
        case ready(SimulationResult)
        case cancelled
    }

    static func load(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog
    ) async -> Result {
        let layouts = Array((session.draft(for: projectID)?.layouts ?? []).prefix(LayoutID.allCases.count))
        guard layouts.count == LayoutID.allCases.count else { return .needsLayouts(count: layouts.count) }

        let parameters = session.eventParameters(for: projectID) ?? catalog.defaultParameters()
        let schedule = DaySchedule(parameters: parameters)
        let analyses = await analysisService.analyses(
            for: layouts,
            parameters: parameters,
            visitorTypes: catalog.visitorTypes,
            focus: schedule.window,
            legend: session.draft(for: projectID)?.legend ?? Legend()
        )
        guard !Task.isCancelled, analyses.count == layouts.count else { return .cancelled }

        var outcomes: [LayoutID: LayoutOutcome] = [:]
        var layoutsByID: [LayoutID: Layout] = [:]
        var analysesByID: [LayoutID: LayoutAnalysis] = [:]
        for (layoutID, (layout, analysis)) in zip(LayoutID.allCases, zip(layouts, analyses)) {
            outcomes[layoutID] = OutcomeBuilder.build(layoutID: layoutID, analysis: analysis, schedule: schedule)
            layoutsByID[layoutID] = layout
            analysesByID[layoutID] = analysis
        }
        return .ready(SimulationResult(
            outcomes: outcomes,
            layouts: layoutsByID,
            analyses: analysesByID,
            visitorTypes: catalog.visitorTypes,
            schedule: schedule
        ))
    }
}

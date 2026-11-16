import Foundation

/// Runs (or reads from the cache) the simulation for the two layouts a project compares, using the
/// project's parameters. Anything the project has not set falls back to the simulator's defaults.
///
/// The busiest time is not a parameter. The simulation is run once with a provisional window, which measures the
/// whole event, and the ten minutes with the most people at the monitored spots become the window the page and
/// the simulator show. When that is another window, the simulation is asked again for it. Both asks go through
/// `AnalysisService` as it is, so the simulation itself is the same as ever.
@MainActor
enum SimulationLoader {
    enum Result {
        case needsLayouts(count: Int)
        case ready(SimulationResult)
        case cancelled
    }

    /// With `savedAnalysis` the layouts and parameters are the ones that run was made from, so its simulator plays
    /// what its page showed. Without one they are the project's as they are now.
    static func load(
        projectID: UUID,
        savedAnalysis: SavedAnalysis? = nil,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)? = nil
    ) async -> Result {
        let layouts = Array((savedAnalysis?.layouts ?? session.comparedLayouts(for: projectID))
            .prefix(LayoutID.allCases.count))
        // One layout is analysed on its own. Two are analysed and compared.
        guard !layouts.isEmpty else { return .needsLayouts(count: 0) }

        let parameters = savedAnalysis?.parameters
            ?? session.eventParameters(for: projectID) ?? catalog.defaultParameters()
        let legend = session.draft(for: projectID)?.legend ?? Legend()
        func analyses(focus: TimeRange) async -> [LayoutAnalysis] {
            await analysisService.analyses(
                for: layouts, parameters: parameters, visitorTypes: catalog.visitorTypes, focus: focus, legend: legend,
                onLiveFrame: onLiveFrame
            )
        }

        let provisional = DaySchedule(parameters: parameters)
        var measured = await analyses(focus: provisional.window)
        guard !Task.isCancelled, measured.count == layouts.count else { return .cancelled }

        let busiest = BusiestWindow.startMinute(
            in: measured, hours: parameters.eventHours, windowMinutes: Int(provisional.windowMinutes)
        )
        let schedule = DaySchedule(parameters: parameters, peakMinute: busiest)
        if schedule.peakMinute != provisional.peakMinute {
            measured = await analyses(focus: schedule.window)
            guard !Task.isCancelled, measured.count == layouts.count else { return .cancelled }
        }
        let analyses = measured

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

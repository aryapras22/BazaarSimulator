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
        /// The layouts to analyse, in place of the ones the saved run or the project compares. A saved run uses them
        /// to show another layout beside its own, with the parameters it was made with.
        layouts layoutsToAnalyse: [Layout]? = nil,
        /// With a saved run, also simulate the project's other layouts with the run's parameters, so every layout is
        /// worked out before the run is shown and any two of them can be put on the cards at once.
        simulatesProject: Bool = false,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)? = nil
    ) async -> Result {
        let layouts = Array((layoutsToAnalyse ?? savedAnalysis?.layouts ?? session.comparedLayouts(for: projectID))
            .prefix(LayoutID.allCases.count))
        // One layout is analysed on its own. Two are analysed and compared.
        guard !layouts.isEmpty else { return .needsLayouts(count: 0) }

        let parameters = savedAnalysis?.parameters
            ?? session.eventParameters(for: projectID) ?? catalog.defaultParameters()
        let legend = session.draft(for: projectID)?.legend ?? Legend()
        // The project's other layouts are simulated in the same go. They are not on the page, but showing one on a
        // card afterwards then reads its run instead of waiting for it.
        let others = savedAnalysis == nil || simulatesProject
            ? (session.draft(for: projectID)?.layouts ?? []).filter { layout in !layouts.contains { $0.id == layout.id } }
            : []
        func analyses(for runLayouts: [Layout], focus: TimeRange) async -> [LayoutAnalysis] {
            await analysisService.analyses(
                for: runLayouts, parameters: parameters, visitorTypes: catalog.visitorTypes, focus: focus, legend: legend,
                onLiveFrame: onLiveFrame
            )
        }

        let provisional = DaySchedule(parameters: parameters)
        let projectLayouts = session.draft(for: projectID)?.layouts ?? []
        let everyLayout = layouts + others
        var everything = await analyses(for: everyLayout, focus: provisional.window)
        guard !Task.isCancelled, everything.count == everyLayout.count else { return .cancelled }

        // One busiest window for all the layouts, so the pair on the cards never changes what the window is, and any
        // two layouts can be shown from this run without simulating again.
        let busiest = BusiestWindow.startMinute(
            in: everything, hours: parameters.eventHours, windowMinutes: Int(provisional.windowMinutes)
        )
        let schedule = DaySchedule(parameters: parameters, peakMinute: busiest)
        if schedule.peakMinute != provisional.peakMinute {
            everything = await analyses(for: everyLayout, focus: schedule.window)
            guard !Task.isCancelled, everything.count == everyLayout.count else { return .cancelled }
        }
        let analyses = Array(everything.prefix(layouts.count))
        let otherAnalyses = Array(everything.suffix(others.count))

        var outcomes: [LayoutID: LayoutOutcome] = [:]
        var layoutsByID: [LayoutID: Layout] = [:]
        var analysesByID: [LayoutID: LayoutAnalysis] = [:]
        for (layoutID, (layout, analysis)) in zip(LayoutID.allCases, zip(layouts, analyses)) {
            let name = LayoutNames.name(of: layout, in: projectLayouts, place: layoutID)
            outcomes[layoutID] = OutcomeBuilder.build(
                layoutID: layoutID, name: name, analysis: analysis, schedule: schedule
            )
            layoutsByID[layoutID] = layout
            analysesByID[layoutID] = analysis
        }
        var result = SimulationResult(
            outcomes: outcomes,
            layouts: layoutsByID,
            analyses: analysesByID,
            visitorTypes: catalog.visitorTypes,
            schedule: schedule
        )
        guard savedAnalysis == nil || simulatesProject else { return .ready(result) }

        // The whole project in one run: the two on the page and the others, which were simulated with them. It ranks
        // the layouts for the Best Layout card, and puts any two of them on the cards without simulating again.
        var ranked = zip(layouts, LayoutID.allCases).compactMap { layout, id in
            outcomes[id].map { ProjectOutcome(layoutID: layout.id, outcome: $0) }
        }
        ranked += zip(others, otherAnalyses).map { layout, analysis in
            let name = LayoutNames.name(of: layout, in: projectLayouts, place: .one)
            return ProjectOutcome(
                layoutID: layout.id,
                outcome: OutcomeBuilder.build(layoutID: .one, name: name, analysis: analysis, schedule: schedule)
            )
        }
        // In the project's own order, so the first of equals is the earlier layout.
        let order = projectLayouts.map(\.id)
        ranked.sort { (order.firstIndex(of: $0.layoutID) ?? .max) < (order.firstIndex(of: $1.layoutID) ?? .max) }
        result.projectOutcomes = ranked
        result.bestProjectLayoutID = ProjectBestLayout.best(
            of: ranked, peakHourText: schedule.peakText, windowMinutes: schedule.windowMinutes
        )
        result.projectRun = ProjectRun(
            layouts: everyLayout.sorted {
                (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
            },
            analyses: Dictionary(zip(everyLayout.map(\.id), everything), uniquingKeysWith: { first, _ in first }),
            outcomes: ranked,
            bestLayoutID: result.bestProjectLayoutID,
            schedule: schedule,
            parameters: parameters,
            visitorTypes: catalog.visitorTypes
        )
        return .ready(result)
    }
}

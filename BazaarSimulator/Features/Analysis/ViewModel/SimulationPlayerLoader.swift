import Foundation

/// Everything the simulation window shows for one layout of one run.
struct PlayerData {
    let outcome: LayoutOutcome
    let layout: Layout
    let replay: SimulationReplay?
    let plan: PlanFrame
    let schedule: DaySchedule
}

/// Finds the footage for a layout of a saved run. The analysis numbers and the replay come from the same run:
/// the run the app still holds if it is the one saved, and otherwise a fresh run of the same layout with the
/// saved parameters, which gives the same crowd because the engine is seeded.
@MainActor
enum SimulationPlayerLoader {
    static func load(target: SimulationTarget, session: any ProjectSessionProtocol) async -> PlayerData? {
        let analyses = session.savedAnalyses(for: target.projectID)
        guard let analysis = target.analysisID.flatMap({ id in analyses.first { $0.id == id } }) ?? analyses.last,
              let index = analysis.layouts.firstIndex(where: { $0.id == target.layoutID }),
              analysis.measurements.indices.contains(index)
        else { return nil }

        let layout = analysis.layouts[index]
        let measurements = analysis.measurements[index]
        let schedule = DaySchedule(parameters: analysis.parameters, peakMinute: analysis.peakMinute)
        let outcome = OutcomeBuilder.build(layoutID: target.slot, analysis: measurements, schedule: schedule)

        let result: SimulationResult
        if let held = session.simulationResult(for: layout.id, in: target.projectID),
           matches(held, measurements, analysis.parameters) {
            result = held
        } else {
            let settings = analysis.parameters.toSimulationSettings()
            let legend = session.draft(for: target.projectID)?.legend ?? Legend()
            let engine = SimulationEngine(layout: layout, settings: settings, legend: legend)
            result = await engine.runWithRecordedFootage(
                durationMinutes: settings.durationMinutes, frameIntervalSeconds: 5.0
            )
        }

        let replay = SimulationReplayBuilder.build(
            result: result,
            layout: layout,
            windowStartMinute: schedule.peakMinute,
            windowMinutes: Int(schedule.windowMinutes)
        )
        return PlayerData(outcome: outcome, layout: layout, replay: replay, plan: measurements.plan, schedule: schedule)
    }

    /// The held run is the one the analysis was measured from when it has footage and the same totals.
    private static func matches(
        _ result: SimulationResult, _ measurements: LayoutAnalysis, _ parameters: EventParameters
    ) -> Bool {
        !result.frames.isEmpty
            && result.startMinutesFromMidnight == parameters.startMinutes
            && result.metrics.arrivals == measurements.simulatedPeople
    }
}

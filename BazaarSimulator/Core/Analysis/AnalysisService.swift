import Foundation

@MainActor
protocol AnalysisServiceProtocol: AnyObject {
    /// One `LayoutAnalysis` per layout, in the same order. Returns fewer if the task is cancelled.
    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend
    ) async -> [LayoutAnalysis]
}

extension AnalysisServiceProtocol {
    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange
    ) async -> [LayoutAnalysis] {
        await analyses(for: layouts, parameters: parameters, visitorTypes: visitorTypes, focus: focus, legend: Legend())
    }
}

/// Runs the crowd simulation for each layout and remembers the results. Changing the layout, the
/// parameters, or the busiest window makes the next request run again.
///
/// Each run happens away from the main thread, so the interface keeps responding while it works.
@MainActor
final class AnalysisService: AnalysisServiceProtocol {
    private var cache: [SimulationInput: LayoutAnalysis] = [:]

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend
    ) async -> [LayoutAnalysis] {
        // Layouts that are not remembered all run at once, each on its own thread.
        var runs: [(input: SimulationInput, grid: NavigationGrid, task: Task<CrowdMeasurements, Never>?)] = []
        for layout in layouts {
            let input = SimulationInput(
                layout: layout, parameters: parameters, visitorTypes: visitorTypes, legend: legend, focus: focus
            )
            let grid = NavigationGrid(layout: layout)
            guard cache[input] == nil else {
                runs.append((input, grid, nil))
                continue
            }
            let setup = CrowdAnalysisBuilder.setup(for: input, grid: grid)
            runs.append((input, grid, Task.detached(priority: .userInitiated) {
                CrowdMeasuringRun(setup: setup).run { Task.isCancelled }
            }))
        }
        let tasks = runs.compactMap(\.task)

        var results: [LayoutAnalysis] = []
        for run in runs {
            if let task = run.task {
                let measured = await withTaskCancellationHandler {
                    await task.value
                } onCancel: {
                    tasks.forEach { $0.cancel() }
                }
                if Task.isCancelled { return results }
                cache[run.input] = CrowdAnalysisBuilder.analysis(for: run.input, grid: run.grid, measured: measured)
            }
            if let analysis = cache[run.input] { results.append(analysis) }
        }
        return results
    }
}

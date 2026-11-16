import Foundation

@MainActor
protocol AnalysisServiceProtocol: AnyObject {
    /// One `LayoutAnalysis` per layout, in the same order. Returns fewer if the task is cancelled.
    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)?
    ) async -> [LayoutAnalysis]

    func cancelAll()
}

extension AnalysisServiceProtocol {
    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange
    ) async -> [LayoutAnalysis] {
        await analyses(
            for: layouts,
            parameters: parameters,
            visitorTypes: visitorTypes,
            focus: focus,
            legend: Legend(),
            onLiveFrame: nil
        )
    }

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend
    ) async -> [LayoutAnalysis] {
        await analyses(
            for: layouts,
            parameters: parameters,
            visitorTypes: visitorTypes,
            focus: focus,
            legend: legend,
            onLiveFrame: nil
        )
    }

    func cancelAll() {}
}

/// Runs the crowd simulation for each layout and remembers the results. Changing the layout, the
/// parameters, or the busiest window makes the next request run again.
///
/// Each run happens away from the main thread, so the interface keeps responding while it works.
@MainActor
final class AnalysisService: AnalysisServiceProtocol {
    private var cache: [SimulationInput: LayoutAnalysis] = [:]
    private var activeTasks: [Task<CrowdMeasurements, Never>] = []

    func cancelAll() {
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
    }

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)? = nil
    ) async -> [LayoutAnalysis] {
        cancelAll()
        var runs: [(input: SimulationInput, grid: NavigationGrid, task: Task<CrowdMeasurements, Never>?)] = []
        for (index, layout) in layouts.enumerated() {
            let input = SimulationInput(
                layout: layout, parameters: parameters, visitorTypes: visitorTypes, legend: legend, focus: focus
            )
            let grid = NavigationGrid(layout: layout)
            guard cache[input] == nil else {
                runs.append((input, grid, nil))
                continue
            }
            let setup = CrowdAnalysisBuilder.setup(for: input, grid: grid)
            let layoutID = layout.id
            let stream = index == 0 ? onLiveFrame : nil
            runs.append((input, grid, Task.detached(priority: .userInitiated) {
                CrowdMeasuringRun(setup: setup).run(
                    onLiveFrame: stream.map { callback in { callback(layoutID, $0, $1) } },
                    isCancelled: { Task.isCancelled }
                )
            }))
        }
        let tasks = runs.compactMap(\.task)
        activeTasks = tasks

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

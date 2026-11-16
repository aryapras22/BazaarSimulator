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

/// Aggregates live simulation progress across all layouts of a single `AnalysisService.analyses` call
/// so the progress bar tracks every layout and never stalls at 100% while another layout finishes.
private final class RunProgressAggregator: @unchecked Sendable {
    private let lock = NSLock()
    private let layoutIDs: [UUID]
    private var progressByLayout: [UUID: Double]
    private var lastReportedProgress = -1.0

    init(layouts: [Layout], cachedLayoutIDs: Set<UUID>) {
        self.layoutIDs = layouts.map(\.id)
        var initial: [UUID: Double] = [:]
        for layout in layouts {
            initial[layout.id] = cachedLayoutIDs.contains(layout.id) ? 1.0 : 0.0
        }
        self.progressByLayout = initial
    }

    func update(layoutID: UUID, progress: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }
        let clamped = min(max(progress, 0.0), 0.98)
        progressByLayout[layoutID] = max(progressByLayout[layoutID] ?? 0.0, clamped)
        return overallProgressLocked(maxCap: 0.98)
    }

    func finish(layoutID: UUID) -> Double {
        lock.lock()
        defer { lock.unlock() }
        progressByLayout[layoutID] = 1.0
        return overallProgressLocked(maxCap: 0.99)
    }

    private func overallProgressLocked(maxCap: Double) -> Double {
        guard !layoutIDs.isEmpty else { return maxCap }
        let sum = layoutIDs.reduce(0.0) { $0 + (progressByLayout[$1] ?? 0.0) }
        let average = min(maxCap, sum / Double(layoutIDs.count))
        lastReportedProgress = max(lastReportedProgress, average)
        return lastReportedProgress
    }
}

/// Runs the crowd simulation for each layout and remembers the results. Changing the layout, the
/// parameters, or the busiest window makes the next request run again.
///
/// Each run happens away from the main thread, so the interface keeps responding while it works.
@MainActor
final class AnalysisService: AnalysisServiceProtocol {
    private var cache: [SimulationInput: LayoutAnalysis] = [:]
    private var activeBatches: [UUID: [Task<CrowdMeasurements, Never>]] = [:]

    func cancelAll() {
        for tasks in activeBatches.values {
            tasks.forEach { $0.cancel() }
        }
        activeBatches.removeAll()
    }

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)? = nil
    ) async -> [LayoutAnalysis] {
        let batchID = UUID()
        var cachedLayoutIDs: Set<UUID> = []
        var prepared: [(layout: Layout, input: SimulationInput, grid: NavigationGrid, setup: CrowdMeasuringSetup?)] = []
        for layout in layouts {
            let input = SimulationInput(
                layout: layout, parameters: parameters, visitorTypes: visitorTypes, legend: legend, focus: focus
            )
            let grid = NavigationGrid(layout: layout)
            if cache[input] != nil {
                cachedLayoutIDs.insert(layout.id)
                prepared.append((layout, input, grid, nil))
            } else {
                prepared.append((layout, input, grid, CrowdAnalysisBuilder.setup(for: input, grid: grid)))
            }
        }

        let previewLayoutID = prepared.first { $0.setup != nil }?.layout.id ?? layouts.first?.id
        let tracker = RunProgressAggregator(layouts: layouts, cachedLayoutIDs: cachedLayoutIDs)

        var runs: [(layoutID: UUID, input: SimulationInput, grid: NavigationGrid, task: Task<CrowdMeasurements, Never>?)] = []
        for entry in prepared {
            guard let setup = entry.setup else {
                runs.append((entry.layout.id, entry.input, entry.grid, nil))
                continue
            }
            let layoutID = entry.layout.id
            let isPreview = layoutID == previewLayoutID
            runs.append((layoutID, entry.input, entry.grid, Task.detached(priority: .userInitiated) {
                CrowdMeasuringRun(setup: setup).run(
                    onLiveFrame: onLiveFrame.map { callback in
                        { visitors, rawProgress in
                            let overall = tracker.update(layoutID: layoutID, progress: rawProgress)
                            callback(layoutID, isPreview ? visitors : [], overall)
                        }
                    },
                    isCancelled: { Task.isCancelled }
                )
            }))
        }

        let tasks = runs.compactMap(\.task)
        if !tasks.isEmpty {
            activeBatches[batchID] = tasks
        }
        defer { activeBatches.removeValue(forKey: batchID) }

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
                if let onLiveFrame, let previewLayoutID {
                    let overall = tracker.finish(layoutID: run.layoutID)
                    onLiveFrame(previewLayoutID, [], overall)
                }
            }
            if let analysis = cache[run.input] { results.append(analysis) }
        }
        return results
    }
}

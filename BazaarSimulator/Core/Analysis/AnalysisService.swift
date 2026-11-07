import Foundation

@MainActor
protocol AnalysisServiceProtocol: AnyObject {
    /// One `LayoutAnalysis` per layout, in the same order. Returns fewer if the task is cancelled.
    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange
    ) async -> [LayoutAnalysis]
}

/// Runs the crowd simulation for each layout and remembers the results. Changing the layout, the
/// parameters, or the busiest window makes the next request run again.
///
/// The simulation runs in small slices and hands control back between them, so the interface keeps
/// responding while it works.
@MainActor
final class AnalysisService: AnalysisServiceProtocol {
    private static let stepsPerSlice = 200

    private var cache: [SimulationInput: LayoutAnalysis] = [:]

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange
    ) async -> [LayoutAnalysis] {
        var results: [LayoutAnalysis] = []
        for layout in layouts {
            let input = SimulationInput(layout: layout, parameters: parameters, visitorTypes: visitorTypes, focus: focus)
            if let cached = cache[input] {
                results.append(cached)
                continue
            }
            await Task.yield()
            let simulation = CrowdSimulation(input: input)
            while !simulation.isFinished {
                simulation.advance(steps: Self.stepsPerSlice)
                await Task.yield()
                if Task.isCancelled { return results }
            }
            let analysis = simulation.makeAnalysis()
            cache[input] = analysis
            results.append(analysis)
        }
        return results
    }
}

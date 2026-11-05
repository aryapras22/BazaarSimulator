import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    let projectID: UUID
    private let session: any ProjectSessionProtocol
    let onBack: () -> Void
    let onSimulate: (LayoutID) -> Void
    let onEdit: (LayoutID) -> Void

    var tab: AnalysisTab = .congestionPoints
    var isParametersPresented: Bool = false
    private(set) var simulationResult: SimulationResult

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        onBack: @escaping () -> Void = {},
        onSimulate: @escaping (LayoutID) -> Void = { _ in },
        onEdit: @escaping (LayoutID) -> Void = { _ in }
    ) {
        self.projectID = projectID
        self.session = session
        self.onBack = onBack
        self.onSimulate = onSimulate
        self.onEdit = onEdit

        let params = session.eventParameters(for: projectID)
        self.simulationResult = SimulationRunner.run(parameters: params)
    }

    var projectName: String {
        session.projects.first { $0.id == projectID }?.name ?? "Project"
    }

    /// Closes the Parameters sheet and re-runs the simulation with whatever was applied.
    func closeParameters() {
        isParametersPresented = false
        refreshSimulation()
    }

    func refreshSimulation() {
        let params = session.eventParameters(for: projectID)
        simulationResult = SimulationRunner.run(parameters: params)
    }

    var activeContent: AnalysisContent {
        content(for: tab)
    }

    func content(for targetTab: AnalysisTab) -> AnalysisContent {
        let engine = CompareRulesEngine(
            outcomes: simulationResult.outcomes,
            peakHourText: simulationResult.peakHourText,
            windowMinutes: simulationResult.windowMinutes
        )
        return engine.content(for: targetTab)
    }

    func outcome(for layout: LayoutID) -> LayoutOutcome {
        simulationResult.outcomes[layout] ?? LayoutOutcome(
            layout: layout,
            name: layout.name,
            windowMinutes: simulationResult.windowMinutes,
            spots: [],
            dayPoints: []
        )
    }
}

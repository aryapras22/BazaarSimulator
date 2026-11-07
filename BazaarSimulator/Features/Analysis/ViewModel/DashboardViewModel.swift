import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    enum Phase: Equatable {
        case loading
        case needsTwoLayouts(count: Int)
        case ready
    }

    let projectID: UUID
    private let session: any ProjectSessionProtocol
    private let analysisService: any AnalysisServiceProtocol
    private let catalog: PresetCatalog
    let onBack: () -> Void
    let onSimulate: (LayoutID) -> Void
    let onEdit: (LayoutID) -> Void

    var tab: AnalysisTab = .congestionPoints
    var isParametersPresented: Bool = false
    private(set) var phase: Phase = .loading
    private(set) var isRunning = false
    private(set) var simulationResult: SimulationResult?
    private var runTask: Task<Void, Never>?

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        onBack: @escaping () -> Void = {},
        onSimulate: @escaping (LayoutID) -> Void = { _ in },
        onEdit: @escaping (LayoutID) -> Void = { _ in }
    ) {
        self.projectID = projectID
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
        self.onBack = onBack
        self.onSimulate = onSimulate
        self.onEdit = onEdit
    }

    var projectName: String {
        session.projects.first { $0.id == projectID }?.name ?? "Project"
    }

    var peakHourText: String {
        simulationResult?.peakHourText ?? ""
    }

    // MARK: Running the simulation

    /// Starts a run in the background. A run already under way is cancelled first.
    func startSimulation() {
        runTask?.cancel()
        runTask = Task { await runSimulation() }
    }

    func runSimulation() async {
        isRunning = true
        defer { isRunning = false }
        switch await SimulationLoader.load(
            projectID: projectID, session: session, analysisService: analysisService, catalog: catalog
        ) {
        case .needsLayouts(let count):
            simulationResult = nil
            phase = .needsTwoLayouts(count: count)
        case .ready(let result):
            simulationResult = result
            phase = .ready
        case .cancelled:
            break
        }
    }

    /// Closes the Parameters sheet and runs the simulation again with whatever was applied.
    func closeParameters() {
        isParametersPresented = false
        startSimulation()
    }

    // MARK: Reading the result

    var activeContent: AnalysisContent? {
        content(for: tab)
    }

    func content(for targetTab: AnalysisTab) -> AnalysisContent? {
        guard let result = simulationResult else { return nil }
        return CompareRulesEngine(
            outcomes: result.outcomes,
            peakHourText: result.peakHourText,
            windowMinutes: result.windowMinutes
        ).content(for: targetTab)
    }

    func floorPlan(for layout: LayoutID) -> Layout? {
        simulationResult?.layouts[layout]
    }

    func plan(for layout: LayoutID) -> PlanFrame {
        simulationResult?.analyses[layout]?.plan ?? .unit
    }

    func outcome(for layout: LayoutID) -> LayoutOutcome {
        simulationResult?.outcomes[layout] ?? LayoutOutcome(
            layout: layout,
            name: layout.name,
            windowMinutes: DaySchedule.defaultWindowMinutes,
            spots: [],
            dayPoints: []
        )
    }
}

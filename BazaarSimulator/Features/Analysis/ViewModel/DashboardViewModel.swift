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
    private(set) var previewVenue: SimulationVenue?
    private(set) var previewFrame = SimulationSceneFrame()
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

    func cancelSimulation() {
        runTask?.cancel()
        runTask = nil
        analysisService.cancelAll()
    }

    func runSimulation() async {
        isRunning = true
        phase = .loading
        preparePreviewVenue()
        defer { isRunning = false }
        let previewLayoutID = previewVenue?.id
        switch await SimulationLoader.load(
            projectID: projectID,
            session: session,
            analysisService: analysisService,
            catalog: catalog,
            onLiveFrame: { [weak self] layoutID, visitors in
                guard layoutID == previewLayoutID else { return }
                Task { @MainActor [weak self] in
                    self?.applyLiveVisitors(visitors)
                }
            }
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

    private func preparePreviewVenue() {
        guard let firstLayout = session.draft(for: projectID)?.layouts.first else {
            previewVenue = nil
            return
        }
        if previewVenue?.id != firstLayout.id {
            let grid = NavigationGrid(layout: firstLayout)
            previewVenue = SimulationVenue(
                id: firstLayout.id,
                blocks: VenueGeometry.blocks(for: firstLayout),
                plan: grid.plan,
                attractions: VenueGeometry.attractions(in: firstLayout),
                seats: VenueGeometry.seats(in: firstLayout)
            )
        }
        previewFrame = SimulationSceneFrame()
    }

    private func applyLiveVisitors(_ visitors: [MeasuredVisitor]) {
        var frame = SimulationSceneFrame()
        frame.visitors = visitors.map { visitor in
            SimulationSceneFrame.Visitor(
                id: visitor.id,
                x: Double(visitor.position.x),
                z: Double(visitor.position.y),
                typeIndex: visitor.typeIndex,
                people: visitor.people,
                isSeated: visitor.isSeated
            )
        }
        previewFrame = frame
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

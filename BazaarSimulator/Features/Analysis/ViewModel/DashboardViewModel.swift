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

    private struct InputSignature: Equatable {
        let layouts: [Layout]
        let legend: Legend
        let parameters: EventParameters?
    }

    let projectID: UUID
    private let session: any ProjectSessionProtocol
    private let analysisService: any AnalysisServiceProtocol
    private let catalog: PresetCatalog
    private let fixedParameters: EventParameters?
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
    private(set) var loadingProgress: Double = 0.0
    private var runTask: Task<Void, Never>?
    private var activeRunID: UUID?
    private var lastInputSignature: InputSignature?

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        fixedParameters: EventParameters? = nil,
        onBack: @escaping () -> Void = {},
        onSimulate: @escaping (LayoutID) -> Void = { _ in },
        onEdit: @escaping (LayoutID) -> Void = { _ in }
    ) {
        self.projectID = projectID
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
        self.fixedParameters = fixedParameters
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

    /// Starts the simulation only when it has not started yet or the project's layouts/parameters changed.
    func startSimulationIfNeeded() {
        let current = currentInputSignature()
        if lastInputSignature == current {
            if runTask != nil || phase != .loading {
                return
            }
        }
        startSimulation()
    }

    /// Starts a run in the background. A run already under way is cancelled first.
    func startSimulation() {
        runTask?.cancel()
        let runID = UUID()
        activeRunID = runID
        lastInputSignature = currentInputSignature()
        runTask = Task { [weak self] in
            await self?.executeSimulation(runID: runID)
        }
    }

    func cancelSimulation() {
        runTask?.cancel()
        runTask = nil
        activeRunID = nil
    }

    func runSimulation() async {
        let runID = UUID()
        activeRunID = runID
        lastInputSignature = currentInputSignature()
        await executeSimulation(runID: runID)
    }

    private func executeSimulation(runID: UUID) async {
        isRunning = true
        phase = .loading
        loadingProgress = 0.0
        preparePreviewVenue(for: nil)
        defer {
            if activeRunID == runID {
                isRunning = false
                runTask = nil
            }
        }
        switch await SimulationLoader.load(
            projectID: projectID,
            session: session,
            analysisService: analysisService,
            catalog: catalog,
            parameters: fixedParameters,
            onLiveFrame: { [weak self] layoutID, visitors, progress in
                Task { @MainActor [weak self] in
                    self?.applyLiveVisitors(visitors, layoutID: layoutID, progress: progress, runID: runID)
                }
            }
        ) {
        case .needsLayouts(let count):
            guard activeRunID == runID, !Task.isCancelled else { return }
            simulationResult = nil
            phase = .needsTwoLayouts(count: count)
        case .ready(let result):
            guard activeRunID == runID, !Task.isCancelled else { return }
            loadingProgress = 1.0
            simulationResult = result
            phase = .ready
        case .cancelled:
            break
        }
    }

    private func currentInputSignature() -> InputSignature {
        let draft = session.draft(for: projectID)
        let layouts = Array((draft?.layouts ?? []).prefix(LayoutID.allCases.count))
        let legend = draft?.legend ?? Legend()
        let parameters = fixedParameters ?? session.eventParameters(for: projectID)
        return InputSignature(layouts: layouts, legend: legend, parameters: parameters)
    }

    private func preparePreviewVenue(for targetLayoutID: UUID?) {
        let layouts = session.draft(for: projectID)?.layouts ?? []
        let targetLayout = (targetLayoutID.flatMap { id in layouts.first { $0.id == id } }) ?? layouts.first
        guard let targetLayout else {
            previewVenue = nil
            return
        }
        if previewVenue?.id != targetLayout.id {
            let grid = NavigationGrid(layout: targetLayout)
            previewVenue = SimulationVenue(
                id: targetLayout.id,
                blocks: VenueGeometry.blocks(for: targetLayout),
                plan: grid.plan,
                attractions: VenueGeometry.attractions(in: targetLayout),
                seats: VenueGeometry.seats(in: targetLayout)
            )
            previewFrame = SimulationSceneFrame()
        } else if targetLayoutID == nil {
            previewFrame = SimulationSceneFrame()
        }
    }

    private func applyLiveVisitors(
        _ visitors: [MeasuredVisitor],
        layoutID: UUID,
        progress: Double,
        runID: UUID
    ) {
        guard phase == .loading, activeRunID == runID else { return }
        loadingProgress = max(loadingProgress, progress)
        if !visitors.isEmpty {
            if previewVenue?.id != layoutID {
                preparePreviewVenue(for: layoutID)
            }
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
    }

    /// Closes the Parameters sheet without resetting an existing saved result.
    func closeParameters() {
        isParametersPresented = false
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

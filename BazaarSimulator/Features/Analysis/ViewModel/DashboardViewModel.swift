import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    enum Phase: Equatable {
        case loading
        case needsLayouts(count: Int)
        case ready
    }

    /// What the page shows: the project's latest analysis, or one saved run opened from the sidebar.
    enum Source: Equatable {
        case latest
        case saved(SavedAnalysis.ID)
    }

    let projectID: UUID
    let source: Source
    private let session: any ProjectSessionProtocol
    private let analysisService: any AnalysisServiceProtocol
    private let catalog: PresetCatalog
    private let fixedParameters: EventParameters?
    let onBack: () -> Void
    let onSimulate: (LayoutID) -> Void
    let onEdit: (LayoutID) -> Void

    var tab: AnalysisTab = .congestionPoints
    var isParametersPresented: Bool = false
    var isInsightsPresented: Bool = false
    private(set) var phase: Phase = .loading
    private(set) var isRunning = false
    private(set) var simulationResult: SimulationResult?
    private(set) var previewVenue: SimulationVenue?
    private(set) var previewFrame = SimulationSceneFrame()
    private(set) var loadingProgress: Double = 0.0
    private var runTask: Task<Void, Never>?
    private var runCount = 0

    init(
        projectID: UUID,
        source: Source = .latest,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        fixedParameters: EventParameters? = nil,
        onBack: @escaping () -> Void = {},
        onSimulate: @escaping (LayoutID) -> Void = { _ in },
        onEdit: @escaping (LayoutID) -> Void = { _ in }
    ) {
        self.projectID = projectID
        self.source = source
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
        self.fixedParameters = fixedParameters
        self.onBack = onBack
        self.onSimulate = onSimulate
        self.onEdit = onEdit
        // A saved run is already complete, so its page shows it from the start and never waits to be told to load.
        if case .saved(let id) = source { showSaved(id) }
    }

    var projectName: String {
        session.projects.first { $0.id == projectID }?.name ?? "Project"
    }

    /// A saved run is a record, so its parameters and layouts cannot be changed from it.
    var canEdit: Bool { source == .latest }

    /// The layouts the page shows, one or two.
    var layoutIDs: [LayoutID] {
        LayoutID.allCases.filter { simulationResult?.layouts[$0] != nil }
    }

    var isSingleLayout: Bool { layoutIDs.count == 1 }

    var title: String {
        guard case .saved(let id) = source, let saved = session.savedAnalysis(id: id, in: projectID) else {
            return projectName
        }
        return "\(projectName) · \(saved.name)"
    }

    var peakHourText: String {
        simulationResult?.peakHourText ?? ""
    }

    // MARK: Running the simulation

    /// What a result was made from. The page runs again only when these change, so coming back to it, or another
    /// window opening over it, never throws away the analysis it is showing.
    private struct Inputs: Equatable {
        let parameters: EventParameters
        let layouts: [Layout]
    }

    private var currentInputs: Inputs { Inputs(parameters: currentParameters, layouts: comparedLayouts) }
    private var shownInputs: Inputs?
    private var runningInputs: Inputs?

    /// Starts a run in the background. A run already under way is cancelled first, unless it is for the same
    /// layouts and parameters, and a page that already shows them stays as it is.
    func startSimulation() {
        if source == .latest {
            if isRunning, runningInputs == currentInputs { return }
            if !isRunning, simulationResult != nil, shownInputs == currentInputs { return }
        }
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
        if case .saved(let id) = source {
            showSaved(id)
            return
        }
        if let saved = unchangedSavedAnalysis() {
            simulationResult = SimulationResult(saved: saved, visitorTypes: catalog.visitorTypes)
            shownInputs = currentInputs
            phase = .ready
            return
        }
        let inputs = currentInputs

        runCount += 1
        let run = runCount
        phase = .loading
        isRunning = true
        runningInputs = inputs
        session.setAnalysisRunning(true, for: projectID)
        defer {
            if run == runCount {
                isRunning = false
                runningInputs = nil
                session.setAnalysisRunning(false, for: projectID)
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
            phase = .needsLayouts(count: count)
        case .ready(let result):
            guard activeRunID == runID, !Task.isCancelled else { return }
            loadingProgress = 1.0
            simulationResult = result
            shownInputs = inputs
            phase = .ready
            record(result)
        case .cancelled:
            break
        }
    }

    private func showSaved(_ id: SavedAnalysis.ID) {
        guard let saved = session.savedAnalysis(id: id, in: projectID),
              let result = SimulationResult(saved: saved, visitorTypes: catalog.visitorTypes)
        else {
            phase = .needsLayouts(count: 0)
            return
        }
        simulationResult = result
        phase = .ready
    }

    private var currentParameters: EventParameters {
        session.eventParameters(for: projectID) ?? catalog.defaultParameters()
    }

    private var comparedLayouts: [Layout] {
        Array((session.draft(for: projectID)?.layouts ?? []).prefix(LayoutID.allCases.count))
    }

    /// The project's latest saved run, when it was made from the layouts and parameters now in the project. Opening
    /// the page then shows it at once, also after the app was restarted, instead of simulating again.
    private func unchangedSavedAnalysis() -> SavedAnalysis? {
        let layouts = comparedLayouts
        guard !layouts.isEmpty,
              let latest = session.savedAnalyses(for: projectID).last,
              latest.matches(parameters: currentParameters, layouts: layouts)
        else { return nil }
        return latest
    }

    /// Keeps a finished analysis as the next saved run in the sidebar.
    private func record(_ result: SimulationResult) {
        let ordered = LayoutID.allCases.filter { result.layouts[$0] != nil }
        let layouts = ordered.compactMap { result.layouts[$0] }
        let analyses = ordered.compactMap { result.analyses[$0] }
        guard !ordered.isEmpty, analyses.count == ordered.count else { return }
        session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: currentParameters,
            peakMinute: result.schedule.peakMinute, in: projectID
        )
    }

    /// Closes the Parameters sheet and runs the simulation again with whatever was applied.
    func closeParameters() {
        isParametersPresented = false
    }

    // MARK: Reading the result

    /// The better layout, why, and the three checks behind it, for the summary under the cards.
    var bestLayout: BestLayoutSummary? {
        guard let result = simulationResult, result.layouts.count == LayoutID.allCases.count else { return nil }
        return BestLayoutSummary(
            engine: CompareRulesEngine(
                outcomes: result.outcomes, peakHourText: result.peakHourText, windowMinutes: result.windowMinutes
            ),
            outcomes: result.outcomes
        )
    }

    /// The three headline numbers when the project has one layout.
    var singleSummary: SingleLayoutSummary? {
        guard let result = simulationResult, result.layouts.count == 1,
              let layout = layoutIDs.first, let outcome = result.outcomes[layout] else { return nil }
        return SingleLayoutSummary(layout: layout, outcome: outcome)
    }

    var activeContent: AnalysisContent? {
        content(for: tab)
    }

    func content(for targetTab: AnalysisTab) -> AnalysisContent? {
        guard let result = simulationResult else { return nil }
        if result.layouts.count == 1, let outcome = result.outcomes[.one] {
            return SingleLayoutContent.content(
                for: targetTab, outcome: outcome, peakHourText: result.peakHourText, windowMinutes: result.windowMinutes
            )
        }
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

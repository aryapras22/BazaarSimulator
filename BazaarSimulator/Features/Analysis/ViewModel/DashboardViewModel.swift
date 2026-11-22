import Foundation
import os
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
    let onBack: () -> Void
    let onSimulate: (LayoutID) -> Void
    let onEdit: (LayoutID) -> Void
    let onOpenParameters: (() -> Void)?

    var tab: AnalysisTab = .congestionPoints
    var isParametersPresented: Bool = false
    var isInsightsPresented: Bool = false
    private(set) var phase: Phase = .loading
    private(set) var isRunning = false
    private(set) var simulationResult: SimulationResult?
    private(set) var previewVenue: SimulationVenue?
    private var previewLayout: Layout?
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
        onBack: @escaping () -> Void = {},
        onSimulate: @escaping (LayoutID) -> Void = { _ in },
        onEdit: @escaping (LayoutID) -> Void = { _ in },
        onOpenParameters: (() -> Void)? = nil
    ) {
        self.projectID = projectID
        self.source = source
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
        self.onBack = onBack
        self.onSimulate = onSimulate
        self.onEdit = onEdit
        self.onOpenParameters = onOpenParameters
        // A saved run is already complete, so its page shows it from the start and never waits to be told to load.
        if case .saved(let id) = source { showSaved(id) }
        // A page for the latest run starts from the saved run made from the same layouts and parameters, if there
        // is one, so a page built anew never opens on the loading page when the analysis is already known.
        if source == .latest, let saved = unchangedSavedAnalysis(),
           let result = SimulationResult(saved: saved, visitorTypes: catalog.visitorTypes) {
            simulationResult = result
            shownInputs = currentInputs
            phase = .ready
        }
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

    /// The project's layouts a card can show instead of its own. Empty on a saved run, which is a record, and when
    /// the project has no layout beyond the ones on the page.
    var layoutChoices: [Layout] {
        let layouts = session.draft(for: projectID)?.layouts ?? []
        return canEdit && layouts.count > 1 ? layouts : []
    }

    /// Shows another of the project's layouts on a card and analyses the new pair.
    func choose(_ id: Layout.ID, for layout: LayoutID) {
        guard canEdit, floorPlan(for: layout)?.id != id else { return }
        session.setComparedLayout(id, at: layout.rawValue - 1, for: projectID)
        phase = .loading
        startSimulation()
    }

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
        Logger(subsystem: "BazaarSimulator", category: "analysis")
            .info("startSimulation: result \(self.simulationResult != nil), shown \(self.shownInputs != nil), running \(self.isRunning)")
        if source == .latest {
            if isRunning, runningInputs == currentInputs { return }
            if !isRunning, simulationResult != nil, shownInputs == currentInputs { return }
        }
        logWhyRunning()
        runTask?.cancel()
        runTask = Task { await runSimulation() }
    }

    /// Cancels the simulation in progress, removes the running row from the sidebar, and leaves the loading screen.
    func cancelSimulation() {
        runCount += 1
        runTask?.cancel()
        runTask = nil
        isRunning = false
        runningInputs = nil
        previewVenue = nil
        previewFrame = SimulationSceneFrame()
        loadingProgress = 0.0
        session.setAnalysisRunning(false, for: projectID)
        onBack()
    }

    /// Writes to the log why a run starts although a result is already on the page, so an unexpected run can be
    /// traced: filter the console for the "analysis" category.
    private func logWhyRunning() {
        let log = Logger(subsystem: "BazaarSimulator", category: "analysis")
        guard source == .latest, let shown = shownInputs else {
            log.info("run: first run on this page")
            return
        }
        let now = currentInputs
        if shown.parameters != now.parameters { log.info("run: parameters changed") }
        if shown.layouts != now.layouts {
            let changed = zip(shown.layouts, now.layouts).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
            log.info("run: layouts changed (count \(shown.layouts.count)->\(now.layouts.count), differing \(changed))")
        }
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
        // Reaching here means the layouts or parameters changed, so the result on the page is for other inputs.
        // The loading page replaces it until the new one is ready.
        simulationResult = nil
        phase = .loading
        loadingProgress = 0.0
        preparePreviewVenue(for: nil)
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
            onLiveFrame: { [weak self] layoutID, visitors, progress in
                Task { @MainActor [weak self] in
                    self?.applyLiveVisitors(visitors, layoutID: layoutID, progress: progress, run: run)
                }
            }
        ) {
        case .needsLayouts(let count):
            guard run == runCount, !Task.isCancelled else { return }
            simulationResult = nil
            phase = .needsLayouts(count: count)
        case .ready(let result):
            guard run == runCount, !Task.isCancelled else { return }
            if currentInputs != inputs {
                await runSimulation()
                return
            }
            loadingProgress = 1.0
            simulationResult = result
            shownInputs = inputs
            phase = .ready
            record(result, parameters: inputs.parameters)
        case .cancelled:
            break
        }
    }

    private func preparePreviewVenue(for targetLayoutID: UUID?) {
        // Every layout of the project is simulated, so the one being previewed may not be on the page.
        let layouts = comparedLayouts + (session.draft(for: projectID)?.layouts ?? [])
        let targetLayout = (targetLayoutID.flatMap { id in layouts.first { $0.id == id } }) ?? layouts.first
        guard let targetLayout else {
            previewVenue = nil
            previewLayout = nil
            return
        }
        if previewVenue == nil || previewLayout != targetLayout {
            let grid = NavigationGrid(layout: targetLayout)
            previewLayout = targetLayout
            previewVenue = SimulationVenue(
                id: UUID(),
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

    private func applyLiveVisitors(_ visitors: [MeasuredVisitor], layoutID: UUID, progress: Double, run: Int) {
        guard phase == .loading, run == runCount else { return }
        loadingProgress = max(loadingProgress, progress)
        guard !visitors.isEmpty else { return }
        if previewLayout?.id != layoutID {
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
        Array(session.comparedLayouts(for: projectID).prefix(LayoutID.allCases.count))
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
    private func record(_ result: SimulationResult, parameters: EventParameters) {
        let ordered = LayoutID.allCases.filter { result.layouts[$0] != nil }
        let layouts = ordered.compactMap { result.layouts[$0] }
        let analyses = ordered.compactMap { result.analyses[$0] }
        guard !ordered.isEmpty, analyses.count == ordered.count else { return }
        session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters,
            peakMinute: result.schedule.peakMinute, in: projectID
        )
    }

    func openParameters() {
        if let onOpenParameters {
            onOpenParameters()
        } else {
            isParametersPresented = true
        }
    }

    /// Closes the Parameters sheet and runs the simulation again with whatever was applied.
    func closeParameters() {
        isParametersPresented = false
        startSimulation()
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

    /// Which of the two cards holds the best layout, when the page compares two. Nil with one layout.
    var bestLayoutID: LayoutID? { bestLayout?.best }

    /// The project layout the best card shows, so a list of the project's layouts can mark it.
    var bestLayoutPlanID: Layout.ID? {
        bestLayoutID.flatMap { simulationResult?.layouts[$0]?.id }
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

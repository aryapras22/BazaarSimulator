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
           let result = SimulationResult(
               saved: saved, visitorTypes: catalog.visitorTypes, projectLayouts: projectLayouts
           ) {
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

    /// What each layout on the page is called: as the project numbers it, not by the card it sits in, so the project's
    /// first layout stays "Layout 1" wherever it is shown.
    var layoutNames: LayoutNames {
        LayoutNames(names: simulationResult?.outcomes.mapValues(\.name) ?? [:])
    }

    /// The project's layouts a card can show instead of its own. Empty when the project has no layout beyond the ones
    /// on the page. A saved run offers them too when it compares two layouts, and picking one shows that pair in place.
    var layoutChoices: [Layout] {
        let layouts = session.draft(for: projectID)?.layouts ?? []
        guard layouts.count > 1 else { return [] }
        switch source {
        case .latest: return layouts
        case .saved: return layoutIDs.count == 2 ? layouts : []
        }
    }

    /// Shows another of the project's layouts on a card. Switching is not a new run: a pair already worked out is shown
    /// at once, and a new pair is worked out quietly, without a "Run N" in the sidebar and without a saved analysis.
    /// On a saved run, which is a record that cannot change, the pair is shown in place and the run is left as it was.
    func choose(_ id: Layout.ID, for layout: LayoutID) {
        guard floorPlan(for: layout)?.id != id else { return }
        if case .saved = source {
            chooseFromSavedRun(id, for: layout)
            return
        }
        session.setComparedLayout(id, at: layout.rawValue - 1, for: projectID)
        // Every layout was simulated together, so any pair is put on the cards from that run at once.
        if let run = currentProjectRun, let switched = run.result(showing: comparedLayouts) {
            runTask?.cancel()
            simulationResult = switched
            shownInputs = currentInputs
            phase = .ready
            return
        }
        if let cached = cachedResult(for: currentInputs) {
            runTask?.cancel()
            simulationResult = cached
            shownInputs = currentInputs
            phase = .ready
            return
        }
        // The page stays as it is while the new pair is worked out, instead of giving way to the loading page.
        quietInputs = currentInputs
        startSimulation()
    }

    /// A saved run is a record, so a switch shows the pair in place and leaves the run, and the live analysis, as they
    /// were. The layout that stays is the run's own. The one picked is the run's if it has it, and the project's
    /// current version otherwise, analysed with the parameters the run was made with. Nothing is saved.
    private func chooseFromSavedRun(_ id: Layout.ID, for layout: LayoutID) {
        guard case .saved(let savedID) = source,
              let saved = session.savedAnalysis(id: savedID, in: projectID)
        else { return }
        var pair = LayoutID.allCases.compactMap { simulationResult?.layouts[$0] }
        let index = layout.rawValue - 1
        guard pair.indices.contains(index) else { return }
        if let other = pair.firstIndex(where: { $0.id == id }) {
            pair.swapAt(index, other)
        } else if let chosen = saved.layouts.first(where: { $0.id == id }) ?? session.layout(id: id, in: projectID) {
            pair[index] = chosen
        } else {
            return
        }
        if pair == saved.layouts {
            savedSwitchTask?.cancel()
            showSaved(savedID)
        } else if let cached = savedSwitchCache.first(where: { $0.layouts == pair }) {
            savedSwitchTask?.cancel()
            simulationResult = cached.result
            showsDerivedPair = true
            phase = .ready
        } else {
            savedSwitchTask?.cancel()
            savedSwitchTask = Task { await runSavedSwitch(to: pair, of: saved) }
        }
    }

    private func runSavedSwitch(to pair: [Layout], of saved: SavedAnalysis) async {
        runCount += 1
        let run = runCount
        isRunning = true
        // The run stays on the page, and the loading page only comes if the other pair takes a while.
        switchLoadingTask?.cancel()
        switchLoadingTask = Task { [weak self] in
            try? await Task.sleep(for: Self.switchLoadingDelay)
            guard let self, !Task.isCancelled, run == self.runCount, self.isRunning else { return }
            self.showLoading()
        }
        defer {
            if run == runCount {
                isRunning = false
                switchLoadingTask?.cancel()
            }
        }
        let loaded = await SimulationLoader.load(
            projectID: projectID,
            savedAnalysis: saved,
            layouts: pair,
            session: session,
            analysisService: analysisService,
            catalog: catalog,
            onLiveFrame: { [weak self] layoutID, visitors, progress in
                Task { @MainActor [weak self] in
                    self?.applyLiveVisitors(visitors, layoutID: layoutID, progress: progress, run: run)
                }
            }
        )
        guard run == runCount, !Task.isCancelled else { return }
        guard case .ready(let result) = loaded else {
            // Nothing to show for that pair, so the run comes back as it was.
            if case .saved(let id) = source { showSaved(id) }
            return
        }
        loadingProgress = 1.0
        simulationResult = result
        showsDerivedPair = true
        savedSwitchCache.removeAll { $0.layouts == pair }
        savedSwitchCache.append((pair, result))
        if savedSwitchCache.count > Self.resultCacheLimit { savedSwitchCache.removeFirst() }
        phase = .ready
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

    /// Replaces the page with the loading page, which shows the simulation under way.
    private func showLoading() {
        simulationResult = nil
        phase = .loading
        loadingProgress = 0.0
        preparePreviewVenue(for: nil)
    }

    /// What a result was made from. The page runs again only when these change, so coming back to it, or another
    /// window opening over it, never throws away the analysis it is showing.
    private struct Inputs: Equatable {
        let parameters: EventParameters
        let layouts: [Layout]
    }

    private var currentInputs: Inputs { Inputs(parameters: currentParameters, layouts: comparedLayouts) }
    private var shownInputs: Inputs?
    private var runningInputs: Inputs?
    /// The pairs of layouts already worked out on this page, for these parameters, so switching back to one shows it at
    /// once. A change to the parameters or to a layout makes its entry stale, as the inputs no longer match.
    private var resultCache: [(inputs: Inputs, result: SimulationResult)] = []
    private static let resultCacheLimit = 12
    /// The inputs of a run that is a switch between layouts: it neither shows a running row in the sidebar nor saves
    /// an analysis. A run for any other inputs, such as new parameters, is a real one.
    private var quietInputs: Inputs?
    /// The pairs a saved run has been switched to, so switching back to one shows it at once.
    private var savedSwitchCache: [(layouts: [Layout], result: SimulationResult)] = []
    private var savedSwitchTask: Task<Void, Never>?
    /// A saved run is showing another pair than the one it was made with, so it cannot be replayed in the simulator.
    private(set) var showsDerivedPair = false
    var canSimulate: Bool { !showsDerivedPair }
    /// For a switch, the loading page only comes if the new pair takes a while, so a quick one never flashes it.
    private var switchLoadingTask: Task<Void, Never>?
    private static let switchLoadingDelay: Duration = .milliseconds(600)

    private func cachedResult(for inputs: Inputs) -> SimulationResult? {
        resultCache.first { $0.inputs == inputs }?.result
    }

    private func remember(_ result: SimulationResult, for inputs: Inputs) {
        resultCache.removeAll { $0.inputs == inputs }
        resultCache.append((inputs, result))
        if resultCache.count > Self.resultCacheLimit { resultCache.removeFirst() }
    }

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
        switchLoadingTask?.cancel()
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
            let result = SimulationResult(
                saved: saved, visitorTypes: catalog.visitorTypes, projectLayouts: projectLayouts
            )
            simulationResult = result
            shownInputs = currentInputs
            if let result { remember(result, for: currentInputs) }
            phase = .ready
            return
        }
        // A pair worked out before, such as the one a saved run's layout switch comes back to, needs no run at all.
        if let cached = cachedResult(for: currentInputs) {
            simulationResult = cached
            shownInputs = currentInputs
            quietInputs = nil
            phase = .ready
            return
        }
        let inputs = currentInputs
        let isQuiet = quietInputs == inputs
        if isQuiet { quietInputs = nil }

        runCount += 1
        let run = runCount
        // Reaching here means the layouts or parameters changed, so the result on the page is for other inputs. The
        // loading page replaces it until the new one is ready. A switch between layouts keeps the page as it is and
        // only shows the loading page if the new pair takes a while.
        switchLoadingTask?.cancel()
        if isQuiet {
            switchLoadingTask = Task { [weak self] in
                try? await Task.sleep(for: Self.switchLoadingDelay)
                guard let self, !Task.isCancelled, run == self.runCount, self.isRunning else { return }
                self.showLoading()
            }
        } else {
            showLoading()
        }
        isRunning = true
        runningInputs = inputs
        if !isQuiet { session.setAnalysisRunning(true, for: projectID) }
        defer {
            if run == runCount {
                isRunning = false
                runningInputs = nil
                switchLoadingTask?.cancel()
                if !isQuiet { session.setAnalysisRunning(false, for: projectID) }
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
                if isQuiet { quietInputs = currentInputs }
                await runSimulation()
                return
            }
            loadingProgress = 1.0
            simulationResult = result
            projectRun = result.projectRun ?? projectRun
            shownInputs = inputs
            remember(result, for: inputs)
            phase = .ready
            if !isQuiet { record(result, parameters: inputs.parameters) }
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
              let result = SimulationResult(
                saved: saved, visitorTypes: catalog.visitorTypes, projectLayouts: projectLayouts
            )
        else {
            phase = .needsLayouts(count: 0)
            return
        }
        simulationResult = result
        showsDerivedPair = false
        phase = .ready
    }

    /// The project's layouts, in the order that numbers them.
    private var projectLayouts: [Layout] { session.draft(for: projectID)?.layouts ?? [] }

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

    /// The best of all the project's layouts, which may not be on a card, and how it does on each of the three checks
    /// against all the others, for the summary above the cards. It is the same whichever pair is on the page.
    var bestLayout: ProjectBestSummary? {
        guard let result = simulationResult, result.layouts.count == LayoutID.allCases.count,
              let bestID = bestChoiceLayoutID,
              let best = projectOutcomes.first(where: { $0.layoutID == bestID })
        else { return nil }
        let place = LayoutID.allCases.first { result.layouts[$0]?.id == bestID }
        return ProjectBestSummary(best: best, all: projectOutcomes, place: place)
    }

    /// How every layout of the project did. A run that covered them all carries it, a result restored from a saved run
    /// gets it from the background run of every layout, and until then it is the two layouts on the page.
    var projectOutcomes: [ProjectOutcome] {
        guard let result = simulationResult else { return [] }
        if !result.projectOutcomes.isEmpty { return result.projectOutcomes }
        if let run = currentProjectRun { return run.outcomes }
        return LayoutID.allCases.compactMap { id in
            guard let layout = result.layouts[id], let outcome = result.outcomes[id] else { return nil }
            return ProjectOutcome(layoutID: layout.id, outcome: outcome)
        }
    }

    /// The best of all the project's layouts, which the list of layouts marks with a trophy and the Best Layout card
    /// names.
    var bestChoiceLayoutID: Layout.ID? {
        guard let result = simulationResult else { return nil }
        return result.bestProjectLayoutID ?? currentProjectRun?.bestLayoutID
            ?? ProjectBestLayout.best(
                of: projectOutcomes, peakHourText: result.peakHourText, windowMinutes: result.windowMinutes
            )
    }

    /// Every layout of the project simulated in one go. Any two of them go on the cards from it at once.
    private var projectRun: ProjectRun?
    private var projectRunTask: Task<Void, Never>?

    /// The run of the whole project, while nothing it was made from has changed.
    private var currentProjectRun: ProjectRun? {
        projectRun.flatMap { $0.isCurrent(parameters: currentParameters, layouts: projectLayouts) ? $0 : nil }
    }

    /// A result made from a saved run, as after a restart, comes from the stored measurements of its own layouts. This
    /// simulates every layout of the project in the background, with the run's busiest window, so the Best Layout
    /// card can name the best of all and the cards can switch layouts without simulating again. A live run already
    /// did all this and needs none of it.
    func refreshProjectBest() {
        guard source == .latest, let result = simulationResult, currentProjectRun == nil, projectRunTask == nil,
              projectLayouts.count >= LayoutID.allCases.count
        else { return }
        let layouts = projectLayouts
        let parameters = currentParameters
        let legend = session.draft(for: projectID)?.legend ?? Legend()
        projectRunTask = Task { [weak self] in
            guard let self else { return }
            let analyses = await analysisService.analyses(
                for: layouts, parameters: parameters, visitorTypes: catalog.visitorTypes,
                focus: result.schedule.window, legend: legend
            )
            projectRunTask = nil
            guard !Task.isCancelled, analyses.count == layouts.count else { return }
            let outcomes = zip(layouts, analyses).map { layout, analysis in
                ProjectOutcome(
                    layoutID: layout.id,
                    outcome: OutcomeBuilder.build(
                        layoutID: .one,
                        name: LayoutNames.name(of: layout, in: layouts, place: .one),
                        analysis: analysis,
                        schedule: result.schedule
                    )
                )
            }
            projectRun = ProjectRun(
                layouts: layouts,
                analyses: Dictionary(zip(layouts.map(\.id), analyses), uniquingKeysWith: { first, _ in first }),
                outcomes: outcomes,
                bestLayoutID: ProjectBestLayout.best(
                    of: outcomes, peakHourText: result.peakHourText, windowMinutes: result.windowMinutes
                ),
                schedule: result.schedule,
                parameters: parameters,
                visitorTypes: catalog.visitorTypes
            )
        }
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

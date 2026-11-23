import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct DashboardViewModelTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", mix: ["a": 50, "b": 50])],
        defaultTotalVisitors: 150
    )

    private func makeModel(layouts: [Layout], parameters: EventParameters? = nil) -> DashboardViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        if let parameters {
            session.setEventParameters(parameters, for: project.id)
        }
        return DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: AnalysisService(),
            catalog: catalog
        )
    }

    /// Waits for the run the model started on its own.
    private func untilReady(_ model: DashboardViewModel) async {
        while model.phase == .loading {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Waits for a switch between layouts to finish. The page stays ready the whole time, so the loading phase cannot
    /// be waited on.
    private func untilShowing(_ model: DashboardViewModel, _ layout: LayoutID, _ id: Layout.ID) async {
        for _ in 0..<500 {
            if model.floorPlan(for: layout)?.id == id, !model.isRunning { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private var twoLayouts: [Layout] {
        [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6)]
    }

    @Test("It starts out loading, with nothing to show")
    func startsLoading() {
        let model = makeModel(layouts: twoLayouts)
        #expect(model.phase == .loading)
        #expect(model.activeContent == nil)
    }

    @Test("A project with no layout has nothing to analyse")
    func needsALayout() async {
        let model = makeModel(layouts: [])
        await model.runSimulation()
        #expect(model.phase == .needsLayouts(count: 0))
        #expect(model.simulationResult == nil)
    }

    @Test("A project with one layout is analysed on its own")
    func oneLayoutIsAnalysed() async throws {
        let model = makeModel(layouts: [TestLayouts.hall()])
        await model.runSimulation()

        #expect(model.phase == .ready)
        #expect(model.isSingleLayout)
        #expect(model.layoutIDs == [.one])
        #expect(model.bestLayout == nil)
        let summary = try #require(model.singleSummary)
        #expect(summary.stats.map(\.title) == ["Stuck Spots", "Time Stuck", "Crowd Level"])
        #expect(summary.stats.map(\.caption) == ["Stuck at once", "Total Duration", "Overall Condition"])
        #expect(summary.stats[2].text == (model.outcome(for: .one).worstSpot.grade.crowdLevel))
    }

    @Test("With one layout every tab shows that layout alone, worded for it")
    func oneLayoutTabs() async throws {
        let model = makeModel(layouts: [TestLayouts.hall()])
        await model.runSimulation()

        for tab in AnalysisTab.allCases {
            let content = try #require(model.content(for: tab))
            #expect(content.recommended == .one)
            #expect(content.tiles.map(\.layout) == [.one])
            #expect(content.rows.map(\.layout) == [.one])
            #expect(content.series.map(\.layout) == [.one])
            #expect(content.cardTitle == tab.title)
            #expect(!content.headline.contains("Layout 2"))
        }
    }

    @Test("With two layouts every tab is built from the simulation")
    func readsFromSimulation() async throws {
        let model = makeModel(layouts: twoLayouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        #expect(model.phase == .ready)
        let result = try #require(model.simulationResult)
        #expect(Set(result.outcomes.keys) == Set(LayoutID.allCases))
        #expect(result.outcomes.values.allSatisfy { !$0.spots.isEmpty })
        for tab in AnalysisTab.shown {
            let content = try #require(model.content(for: tab))
            #expect(content.tiles.count == 2)
            // The chart plots every sampled hour, and names the morning, the busiest time and the evening.
            #expect(content.series.allSatisfy { $0.points.count >= 1 })
            #expect(content.hourLabels.count <= 3)
            #expect(content.hourLabels.count <= (content.series.first?.points.count ?? 0))
        }
    }

    @Test("Without applied parameters the catalog's defaults are used")
    func fallsBackToDefaults() async throws {
        let model = makeModel(layouts: twoLayouts)
        await model.runSimulation()
        #expect(!model.peakHourText.isEmpty)
        // The sample hours are the two-hourly grid plus the busiest time the simulation found.
        let schedule = try #require(model.simulationResult?.schedule)
        let expected = DaySchedule(parameters: catalog.defaultParameters(), peakMinute: schedule.peakMinute)
        #expect(model.simulationResult?.sampleHours == expected.sampleHours)
        #expect(model.simulationResult?.sampleHours.contains(schedule.peakHour) == true)
    }

    @Test("Applied parameters change the result")
    func parametersChangeResult() async throws {
        var quiet = TestLayouts.parameters
        quiet.totalVisitors = 100
        var busy = quiet
        busy.totalVisitors = 2500

        let quietModel = makeModel(layouts: twoLayouts, parameters: quiet)
        let busyModel = makeModel(layouts: twoLayouts, parameters: busy)
        await quietModel.runSimulation()
        await busyModel.runSimulation()

        // The busiest time is read from each simulation, and always lies inside the event hours.
        for model in [quietModel, busyModel] {
            let schedule = try #require(model.simulationResult?.schedule)
            #expect(schedule.peakMinute >= quiet.eventHours.startMinute)
            #expect(schedule.window.endMinute <= quiet.eventHours.endMinute)
        }
        let quietDensity = try #require(quietModel.simulationResult?.outcomes[.one]?.D)
        let busyDensity = try #require(busyModel.simulationResult?.outcomes[.one]?.D)
        #expect(busyDensity > quietDensity)
    }

    @Test("Closing the Parameters sheet dismisses it without resetting a ready result")
    func closingParameters() async {
        let model = makeModel(layouts: twoLayouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        #expect(model.phase == .ready)
        model.isParametersPresented = true
        model.closeParameters()
        #expect(!model.isParametersPresented)
        #expect(model.phase == .ready)
    }

    @Test("Starting again keeps the ready result when the inputs are unchanged")
    func startingAgainKeepsReadyResult() async {
        let model = makeModel(layouts: twoLayouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let previousAnalyses = model.simulationResult?.analyses
        model.startSimulation()
        #expect(model.phase == .ready)
        #expect(model.simulationResult?.analyses == previousAnalyses)
    }

    @Test("Picking another layout for a card analyses the new pair, and picking the other card's layout swaps them")
    func choosingLayouts() async {
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id && model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(model.layoutChoices.map(\.id) == layouts.map(\.id))

        let peakBefore = model.simulationResult?.schedule.peakMinute
        model.choose(layouts[2].id, for: .two)
        // Every layout was simulated in the first run, so the new pair is on the cards at once, in the same window.
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(model.simulationResult?.schedule.peakMinute == peakBefore)
        await untilShowing(model, .two, layouts[2].id)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id && model.floorPlan(for: .two)?.id == layouts[2].id)

        model.choose(layouts[0].id, for: .two)
        await untilShowing(model, .two, layouts[0].id)
        #expect(model.floorPlan(for: .one)?.id == layouts[2].id && model.floorPlan(for: .two)?.id == layouts[0].id)
    }

    @Test("Switching a card's layout makes no new run, and switching back shows the pair at once")
    func switchingLayoutsMakesNoNewRun() async {
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(TestLayouts.parameters, for: project.id)
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog, onBack: {}
        )
        await model.runSimulation()
        #expect(session.savedAnalyses(for: project.id).count == 1)

        model.choose(layouts[2].id, for: .two)
        await untilShowing(model, .two, layouts[2].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        // The switch is not saved as a run, and the sidebar never showed one under way.
        #expect(session.savedAnalyses(for: project.id).count == 1)
        #expect(!session.isSimulating(project.id))

        // The first pair was worked out already, so it comes back without loading.
        model.choose(layouts[1].id, for: .two)
        #expect(model.phase == .ready)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(session.savedAnalyses(for: project.id).count == 1)
    }

    @Test("The best layout is the same whichever pair of layouts is on the cards")
    func bestLayoutDoesNotDependOnThePair() async {
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let best = model.bestChoiceLayoutID
        #expect(best != nil)
        #expect(model.bestLayout?.name != nil)
        let name = model.bestLayout?.name

        model.choose(layouts[2].id, for: .two)
        await untilShowing(model, .two, layouts[2].id)
        #expect(model.bestChoiceLayoutID == best)
        #expect(model.bestLayout?.name == name)

        model.choose(layouts[0].id, for: .two)
        await untilShowing(model, .two, layouts[0].id)
        #expect(model.bestChoiceLayoutID == best)
        #expect(model.bestLayout?.name == name)
    }

    @Test("A layout keeps its project number whichever card it is switched onto")
    func layoutNumbersFollowTheProject() async {
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        #expect(model.layoutNames.name(.one) == "Layout 1")
        #expect(model.layoutNames.name(.two) == "Layout 2")

        // The project's third layout on the second card is "Layout 3", not "Layout 2".
        model.choose(layouts[2].id, for: .two)
        await untilShowing(model, .two, layouts[2].id)
        #expect(model.layoutNames.name(.one) == "Layout 1")
        #expect(model.layoutNames.name(.two) == "Layout 3")

        // The project's first layout moved to the second card is still "Layout 1".
        model.choose(layouts[0].id, for: .two)
        await untilShowing(model, .two, layouts[0].id)
        #expect(model.layoutNames.name(.two) == "Layout 1")
        #expect(model.layoutNames.name(.one) == "Layout 3")
    }

    @Test("A saved run switches a layout in place, stays on that run, and saves nothing")
    func savedRunSwitchesLayoutsInPlace() async throws {
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(TestLayouts.parameters, for: project.id)
        let live = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog, onBack: {}
        )
        await live.runSimulation()
        let saved = try #require(session.savedAnalyses(for: project.id).first)
        let comparedBefore = session.comparedLayouts(for: project.id).map(\.id)

        let record = DashboardViewModel(
            projectID: project.id, source: .saved(saved.id), session: session, analysisService: AnalysisService(),
            catalog: catalog
        )
        #expect(record.layoutChoices.map(\.id) == layouts.map(\.id))
        #expect(record.canSimulate)

        record.choose(layouts[2].id, for: .two)
        await untilShowing(record, .two, layouts[2].id)

        // The record shows the other pair in place. It is not replayable, and the live analysis is untouched.
        #expect(record.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(record.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(!record.canSimulate)
        #expect(session.comparedLayouts(for: project.id).map(\.id) == comparedBefore)
        #expect(session.savedAnalyses(for: project.id).count == 1)
        #expect(!session.isSimulating(project.id))

        // Picking the run's own layout again brings the run back as it was.
        record.choose(layouts[1].id, for: .two)
        #expect(record.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(record.canSimulate)
    }

    @Test("Cancelling during loading stops the simulation, clears running state, saves no run, and navigates back")
    func cancellingStopsAndClearsSidebarRunning() async {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: twoLayouts), for: project.id)
        var params = TestLayouts.parameters
        params.totalVisitors = 4000
        session.setEventParameters(params, for: project.id)
        var didGoBack = false
        let model = DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: AnalysisService(),
            catalog: catalog,
            onBack: { didGoBack = true }
        )

        model.startSimulation()
        await Task.yield()
        #expect(model.phase == .loading)
        #expect(session.isSimulating(project.id))

        model.cancelSimulation()
        #expect(didGoBack)
        #expect(!model.isRunning)
        #expect(!session.isSimulating(project.id))
        #expect(session.savedAnalyses(for: project.id).isEmpty)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(!session.isSimulating(project.id))
        #expect(session.savedAnalyses(for: project.id).isEmpty)
    }
}

@MainActor
private final class GatedAnalysisService: AnalysisServiceProtocol {
    struct Call {
        let layouts: [Layout]
        let parameters: EventParameters
    }

    private(set) var calls: [Call] = []
    private var firstCallStarted: CheckedContinuation<Void, Never>?
    private var firstCallGate: CheckedContinuation<Void, Never>?
    private var hasPausedFirstCall = false
    private let pausesFirstCall: Bool

    init(pausesFirstCall: Bool = false) {
        self.pausesFirstCall = pausesFirstCall
    }

    func waitForFirstCall() async {
        if !calls.isEmpty { return }
        await withCheckedContinuation { continuation in
            firstCallStarted = continuation
        }
    }

    func releaseFirstCall() {
        firstCallGate?.resume()
        firstCallGate = nil
    }

    func analyses(
        for layouts: [Layout],
        parameters: EventParameters,
        visitorTypes: [VisitorType],
        focus: TimeRange,
        legend: Legend,
        onLiveFrame: (@Sendable (UUID, [MeasuredVisitor], Double) -> Void)?
    ) async -> [LayoutAnalysis] {
        calls.append(Call(layouts: layouts, parameters: parameters))
        if pausesFirstCall, !hasPausedFirstCall {
            hasPausedFirstCall = true
            firstCallStarted?.resume()
            firstCallStarted = nil
            await withCheckedContinuation { continuation in
                firstCallGate = continuation
            }
        }
        guard !Task.isCancelled else { return [] }
        return layouts.map { layout in
            let spot = SpotMeasurement(
                number: 1, name: "Near B1", position: SIMD2(4, 5),
                densitySamples: [0.2, 0.5], peopleSamples: [2, 5]
            )
            var result = LayoutAnalysis(
                layoutID: layout.id,
                eventStartMinute: parameters.eventHours.startMinute,
                sampleIntervalSeconds: 60,
                spots: [spot],
                flowPerMinute: [2, 3],
                simulatedPeople: layout.objects.count,
                totalPeople: parameters.totalVisitors
            )
            result.plan = PlanFrame(origin: .zero, size: layout.sizeM)
            return result
        }
    }

    func cancelAll() {}
}

@MainActor
@Suite("DashboardLoadRaceTests")
struct DashboardLoadRaceTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", mix: ["a": 50, "b": 50])]
    )

    private func untilSettled(_ model: DashboardViewModel) async {
        for _ in 0..<200 {
            if model.phase != .loading && !model.isRunning {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("Editing a layout while a simulation is in flight discards the stale result and re-runs")
    func layoutEditDuringLoadRerunsInsteadOfCommittingStaleResult() async {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let original = TestLayouts.hall(booths: 3)
        var edited = original
        edited.name = "Edited Hall"
        edited.objects.append(LayoutObject(
            kind: .booth,
            label: "B4",
            placement: Placement(center: SIMD2(19, 2.5), sizeM: SIMD2(3, 2)),
            openSides: [.bottom]
        ))
        session.setDraft(ProjectDraft(name: "P", layouts: [original]), for: project.id)
        let service = GatedAnalysisService(pausesFirstCall: true)
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: service, catalog: catalog
        )

        model.startSimulation()
        await service.waitForFirstCall()
        session.updateLayout(edited, in: project.id)
        service.releaseFirstCall()
        await untilSettled(model)

        #expect(model.phase == .ready)
        #expect(model.floorPlan(for: .one) == edited)
        #expect(model.simulationResult?.analyses[.one]?.simulatedPeople == edited.objects.count)
        #expect(session.savedAnalyses(for: project.id).count == 1)
        #expect(session.savedAnalyses(for: project.id).first?.layouts == [edited])
    }

    @Test("Changing parameters while a simulation is in flight re-runs instead of saving stale results")
    func parameterChangeDuringLoadRerunsAndRecordsMatchingParameters() async {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let layout = TestLayouts.hall(booths: 3)
        session.setDraft(ProjectDraft(name: "P", layouts: [layout]), for: project.id)
        var initialParams = catalog.defaultParameters()
        initialParams.totalVisitors = 200
        var updatedParams = initialParams
        updatedParams.totalVisitors = 900
        session.setEventParameters(initialParams, for: project.id)
        let service = GatedAnalysisService(pausesFirstCall: true)
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: service, catalog: catalog
        )

        model.startSimulation()
        await service.waitForFirstCall()
        session.setEventParameters(updatedParams, for: project.id)
        service.releaseFirstCall()
        await untilSettled(model)

        #expect(model.phase == .ready)
        #expect(service.calls.last?.parameters == updatedParams)
        #expect(model.simulationResult?.analyses[.one]?.totalPeople == updatedParams.totalVisitors)
        #expect(session.savedAnalyses(for: project.id).count == 1)
        let saved = session.savedAnalyses(for: project.id).first
        #expect(saved?.parameters == updatedParams)
        #expect(saved?.analyses.first?.totalPeople == updatedParams.totalVisitors)
    }

    @Test("Editing a layout rebuilds previewVenue with a new ID and updated geometry")
    func editingLayoutRebuildsPreviewVenue() async throws {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let original = TestLayouts.hall(booths: 3)
        var edited = original
        edited.objects.append(LayoutObject(
            kind: .booth,
            label: "B4",
            placement: Placement(center: SIMD2(19, 2.5), sizeM: SIMD2(3, 2)),
            openSides: [.bottom]
        ))
        session.setDraft(ProjectDraft(name: "P", layouts: [original]), for: project.id)
        let service = GatedAnalysisService()
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: service, catalog: catalog
        )

        await model.runSimulation()
        let initialVenue = try #require(model.previewVenue)

        session.updateLayout(edited, in: project.id)
        await model.runSimulation()
        let updatedVenue = try #require(model.previewVenue)

        #expect(updatedVenue.id != initialVenue.id)
        #expect(updatedVenue.blocks == VenueGeometry.blocks(for: edited))
        #expect(updatedVenue.attractions == VenueGeometry.attractions(in: edited))
    }
}

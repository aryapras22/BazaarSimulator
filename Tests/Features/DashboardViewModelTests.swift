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

    private var threeLayouts: [Layout] {
        [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6), TestLayouts.hall(booths: 9)]
    }

    @Test("The best layout is always on the left card, and picking a layout switches only the right card")
    func bestLayoutStaysOnTheLeft() async throws {
        let layouts = threeLayouts
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let best = try #require(model.bestChoiceLayoutID)
        let others = layouts.filter { $0.id != best }
        #expect(model.floorPlan(for: .one)?.id == best)
        #expect(model.floorPlan(for: .two)?.id != best)
        // Only the right card has a list, and it holds the layouts other than the best.
        #expect(model.layoutChoices(for: .one).isEmpty)
        #expect(model.layoutChoices(for: .two).map(\.id) == others.map(\.id))

        let shownRight = model.floorPlan(for: .two)?.id
        let next = try #require(others.first { $0.id != shownRight })
        let peakBefore = model.simulationResult?.schedule.peakMinute
        model.choose(next.id, for: .two)
        // Every layout was simulated in the first run, so the new pair is on the cards at once, in the same window.
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .one)?.id == best)
        #expect(model.floorPlan(for: .two)?.id == next.id)
        #expect(model.simulationResult?.schedule.peakMinute == peakBefore)

        // The left card is not switched.
        model.choose(others[0].id, for: .one)
        #expect(model.floorPlan(for: .one)?.id == best)
        #expect(model.floorPlan(for: .two)?.id == next.id)
    }

    @Test("Switching the right card makes no new run, and switching back shows the pair at once")
    func switchingLayoutsMakesNoNewRun() async throws {
        let layouts = threeLayouts
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(TestLayouts.parameters, for: project.id)
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog, onBack: {}
        )
        await model.runSimulation()
        #expect(session.savedAnalyses(for: project.id).count == 1)
        let best = try #require(model.bestChoiceLayoutID)
        let others = layouts.filter { $0.id != best }
        let firstRight = try #require(model.floorPlan(for: .two)?.id)
        let other = try #require(others.first { $0.id != firstRight })

        model.choose(other.id, for: .two)
        #expect(model.floorPlan(for: .two)?.id == other.id)
        // The switch is not saved as a run, and the sidebar never showed one under way.
        #expect(session.savedAnalyses(for: project.id).count == 1)
        #expect(!session.isSimulating(project.id))

        // The first pair was worked out already, so it comes back without loading.
        model.choose(firstRight, for: .two)
        #expect(model.phase == .ready)
        #expect(model.floorPlan(for: .two)?.id == firstRight)
        #expect(session.savedAnalyses(for: project.id).count == 1)
    }

    @Test("The best layout is the same whichever layout is on the right card")
    func bestLayoutDoesNotDependOnThePair() async throws {
        let layouts = threeLayouts
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let best = try #require(model.bestChoiceLayoutID)
        let name = model.bestLayout?.name
        #expect(name != nil)

        for other in layouts.filter({ $0.id != best }) {
            model.choose(other.id, for: .two)
            #expect(model.bestChoiceLayoutID == best)
            #expect(model.bestLayout?.name == name)
            #expect(model.floorPlan(for: .one)?.id == best)
        }
    }

    @Test("A layout keeps its project number whichever card it is on")
    func layoutNumbersFollowTheProject() async throws {
        let layouts = threeLayouts
        let model = makeModel(layouts: layouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let best = try #require(model.bestChoiceLayoutID)
        func number(of id: Layout.ID) -> String { "Layout \((layouts.firstIndex { $0.id == id } ?? 0) + 1)" }

        #expect(model.layoutNames.name(.one) == number(of: best))
        for other in layouts.filter({ $0.id != best }) {
            // Whichever layout is on the right card is named by its place in the project, not by its card.
            model.choose(other.id, for: .two)
            #expect(model.layoutNames.name(.two) == number(of: other.id))
            #expect(model.layoutNames.name(.one) == number(of: best))
        }
    }

    @Test("A saved run keeps the best layout on the left, switches the right card in place, and saves nothing")
    func savedRunSwitchesLayoutsInPlace() async throws {
        let layouts = threeLayouts
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
        #expect(record.phase == .ready)
        #expect(record.simulationResult?.projectRun == nil)
        let best = try #require(record.bestChoiceLayoutID)
        #expect(record.floorPlan(for: .one)?.id == best)
        #expect(record.layoutChoices(for: .one).isEmpty)
        #expect(record.layoutChoices(for: .two).count == 2)

        let shownRight = try #require(record.floorPlan(for: .two)?.id)
        let other = try #require(layouts.first { $0.id != best && $0.id != shownRight })
        record.choose(other.id, for: .two)
        await untilShowing(record, .two, other.id)
        #expect(record.floorPlan(for: .two)?.id == other.id)
        #expect(record.floorPlan(for: .one)?.id == best)
        #expect(!record.isRunning)

        // The live analysis is untouched and nothing was saved.
        #expect(session.comparedLayouts(for: project.id).map(\.id) == comparedBefore)
        #expect(session.savedAnalyses(for: project.id).count == 1)
        #expect(!session.isSimulating(project.id))
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

extension DashboardViewModelTests {
    private func stubAnalysis(
        for layout: Layout,
        parameters: EventParameters,
        density: Float,
        people: Int
    ) -> LayoutAnalysis {
        let count = max(parameters.eventHours.endMinute - parameters.eventHours.startMinute, 1)
        let spot = SpotMeasurement(
            number: 1,
            name: "Near B1",
            position: SIMD2(4, 5),
            densitySamples: Array(repeating: density, count: count),
            peopleSamples: Array(repeating: people, count: count)
        )
        var analysis = LayoutAnalysis(
            layoutID: layout.id,
            eventStartMinute: parameters.eventHours.startMinute,
            sampleIntervalSeconds: 60,
            spots: [spot],
            flowPerMinute: Array(repeating: Double(people), count: count),
            simulatedPeople: people * 10,
            totalPeople: parameters.totalVisitors
        )
        analysis.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        return analysis
    }

    @Test("Opening a saved run shows stored measurements immediately without simulating")
    func openingSavedRunShowsStoredMeasurementsWithoutSimulating() async throws {
        let layouts = twoLayouts
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let parameters = TestLayouts.parameters
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(parameters, for: project.id)
        let storedAnalyses = [
            stubAnalysis(for: layouts[0], parameters: parameters, density: 0.3, people: 3),
            stubAnalysis(for: layouts[1], parameters: parameters, density: 1.1, people: 11)
        ]
        let saved = try #require(
            session.recordAnalysis(
                layouts: layouts,
                analyses: storedAnalyses,
                parameters: parameters,
                peakMinute: parameters.eventHours.startMinute + 60,
                in: project.id
            )
        )
        let spy = GatedAnalysisService()
        let model = DashboardViewModel(
            projectID: project.id,
            source: .saved(saved.id),
            session: session,
            analysisService: spy,
            catalog: catalog
        )

        #expect(model.phase == .ready)
        #expect(model.simulationResult?.analyses[.one] == storedAnalyses[0])
        #expect(model.simulationResult?.analyses[.two] == storedAnalyses[1])
        #expect(model.simulationResult?.replay(for: .one) == nil)
        #expect(spy.calls.isEmpty)

        await model.runSimulation()
        #expect(model.phase == .ready)
        #expect(model.simulationResult?.analyses[.one] == storedAnalyses[0])
        #expect(model.simulationResult?.analyses[.two] == storedAnalyses[1])
        #expect(model.simulationResult?.replay(for: .one) == nil)
        #expect(spy.calls.isEmpty)

        model.startSimulation()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(20))
        #expect(model.phase == .ready)
        #expect(model.simulationResult?.analyses[.one] == storedAnalyses[0])
        #expect(model.simulationResult?.analyses[.two] == storedAnalyses[1])
        #expect(model.simulationResult?.replay(for: .one) == nil)
        #expect(spy.calls.isEmpty)
    }

    @Test("Recording a run stores the pinned layout pair order shown on the cards")
    func runSimulationRecordsPinnedLayoutOrder() async throws {
        let layouts = twoLayouts
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let parameters = TestLayouts.parameters
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(parameters, for: project.id)

        let service = GatedAnalysisService { layout, params in
            let isFirst = layout.id == layouts[0].id
            return stubAnalysis(
                for: layout,
                parameters: params,
                density: isFirst ? 1.8 : 0.1,
                people: isFirst ? 20 : 1
            )
        }
        let model = DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: service,
            catalog: catalog
        )

        await model.runSimulation()

        let expectedOrder = [layouts[1].id, layouts[0].id]
        #expect(model.phase == .ready)
        #expect(model.floorPlan(for: .one)?.id == layouts[1].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[0].id)
        let saved = try #require(session.savedAnalyses(for: project.id).first)
        #expect(saved.layouts.map(\.id) == expectedOrder)
        #expect(saved.analyses.map(\.layoutID) == expectedOrder)
    }

    private func untilLoading(_ model: DashboardViewModel) async {
        for _ in 0..<100 {
            if model.phase == .loading { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func untilDerivedPairReady(_ model: DashboardViewModel, rightID: Layout.ID) async {
        for _ in 0..<200 {
            if model.simulationResult?.layouts[.two]?.id == rightID, !model.isRunning, model.showsDerivedPair {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func rankedService(for layouts: [Layout]) -> GatedAnalysisService {
        GatedAnalysisService { layout, params in
            let rank = layouts.firstIndex { $0.id == layout.id } ?? layouts.count
            return stubAnalysis(
                for: layout,
                parameters: params,
                density: 0.2 + Float(rank) * 0.4,
                people: 2 + rank * 4
            )
        }
    }

    private struct SavedFixture {
        let session: ProjectSession
        let projectID: UUID
        let saved: SavedAnalysis
    }

    private func makeSavedSession(
        layouts: [Layout],
        parameters: EventParameters? = nil
    ) throws -> SavedFixture {
        let parameters = parameters ?? TestLayouts.parameters
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        session.setEventParameters(parameters, for: project.id)
        let savedLayouts = Array(layouts.prefix(2))
        let analyses = savedLayouts.enumerated().map { index, layout in
            stubAnalysis(
                for: layout,
                parameters: parameters,
                density: 0.2 + Float(index) * 0.4,
                people: 2 + index * 4
            )
        }
        let saved = try #require(
            session.recordAnalysis(
                layouts: savedLayouts,
                analyses: analyses,
                parameters: parameters,
                peakMinute: parameters.eventHours.startMinute + 60,
                in: project.id
            )
        )
        return SavedFixture(session: session, projectID: project.id, saved: saved)
    }

    @Test("Cancelling a slow saved-run switch restores the original pair without calling onBack")
    func cancellingSlowSavedSwitchRestoresOriginalPairWithoutGoingBack() async throws {
        let layouts = threeLayouts
        let fixture = try makeSavedSession(layouts: layouts)
        let service = rankedService(for: layouts)
        var didGoBack = false
        let model = DashboardViewModel(
            projectID: fixture.projectID,
            source: .saved(fixture.saved.id),
            session: fixture.session,
            analysisService: service,
            catalog: catalog,
            onBack: { didGoBack = true }
        )

        service.pauseNextCall()
        defer { service.releasePausedCall() }
        model.choose(layouts[2].id, for: .two)
        await untilLoading(model)
        #expect(model.phase == .loading)

        model.cancelSimulation()
        #expect(!didGoBack)
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(model.layoutNames.name(.two) == "Layout 2")
        #expect(!model.showsDerivedPair)

        service.releasePausedCall()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(!model.showsDerivedPair)
    }

    @Test("Cancelling a slow saved-run switch from a derived pair restores that derived pair without calling onBack")
    func cancellingSlowSavedSwitchFromDerivedPairRestoresDerivedPair() async throws {
        let layouts = [
            TestLayouts.hall(booths: 3),
            TestLayouts.hall(booths: 5),
            TestLayouts.hall(booths: 7),
            TestLayouts.hall(booths: 9)
        ]
        let fixture = try makeSavedSession(layouts: layouts)
        let service = rankedService(for: layouts)
        var didGoBack = false
        let model = DashboardViewModel(
            projectID: fixture.projectID,
            source: .saved(fixture.saved.id),
            session: fixture.session,
            analysisService: service,
            catalog: catalog,
            onBack: { didGoBack = true }
        )

        model.choose(layouts[2].id, for: .two)
        await untilDerivedPairReady(model, rightID: layouts[2].id)
        #expect(model.showsDerivedPair)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)

        service.pauseNextCall()
        defer { service.releasePausedCall() }
        model.choose(layouts[3].id, for: .two)
        await untilLoading(model)
        #expect(model.phase == .loading)

        model.cancelSimulation()
        #expect(!didGoBack)
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(model.layoutNames.name(.two) == "Layout 3")
        #expect(model.showsDerivedPair)

        service.releasePausedCall()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(model.showsDerivedPair)
    }

    @Test("Pending saved-run switch reports target pair, simulates it, and cancels when choosing original back")
    func pendingSavedSwitchReportsTargetPairAndChoosingOriginalCancelsIt() async throws {
        let layouts = threeLayouts
        let fixture = try makeSavedSession(layouts: layouts)
        let service = rankedService(for: layouts)
        var simulated: [(LayoutID, [Layout.ID]?)] = []
        let model = DashboardViewModel(
            projectID: fixture.projectID,
            source: .saved(fixture.saved.id),
            session: fixture.session,
            analysisService: service,
            catalog: catalog,
            onSimulate: { simulated.append(($0, $1)) }
        )

        service.pauseNextCall()
        defer { service.releasePausedCall() }
        model.choose(layouts[2].id, for: .two)
        await service.waitForPausedCall()

        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(model.layoutNames.name(.one) == "Layout 1")
        #expect(model.layoutNames.name(.two) == "Layout 3")
        model.simulate(.two)
        #expect(simulated.last?.0 == .two)
        #expect(simulated.last?.1 == [layouts[0].id, layouts[2].id])

        model.choose(layouts[1].id, for: .two)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(model.layoutNames.name(.two) == "Layout 2")
        #expect(!model.isRunning)
        #expect(model.phase == .ready)
        #expect(!model.showsDerivedPair)
        model.simulate(.two)
        #expect(simulated.last?.0 == .two)
        #expect(simulated.last?.1 == nil)

        service.releasePausedCall()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(!model.isRunning)
        #expect(model.phase == .ready)
    }

    @Test("Pending quiet live switch reports target pair and cancels when choosing original back")
    func pendingQuietLiveSwitchReportsTargetPairAndChoosingOriginalCancelsIt() async throws {
        let layouts = threeLayouts
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: Array(layouts.prefix(2))), for: project.id)
        session.setEventParameters(TestLayouts.parameters, for: project.id)
        let service = rankedService(for: layouts)
        var simulated: [(LayoutID, [Layout.ID]?)] = []
        let model = DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: service,
            catalog: catalog,
            onSimulate: { simulated.append(($0, $1)) }
        )

        await model.runSimulation()
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)

        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        service.pauseNextCall()
        defer { service.releasePausedCall() }
        model.choose(layouts[2].id, for: .two)
        await service.waitForPausedCall()

        #expect(model.floorPlan(for: .two)?.id == layouts[2].id)
        #expect(model.layoutNames.name(.two) == "Layout 3")
        #expect(session.comparedLayouts(for: project.id).map(\.id) == [layouts[0].id, layouts[2].id])
        model.simulate(.two)
        #expect(simulated.last?.0 == .two)
        #expect(simulated.last?.1 == nil)

        model.choose(layouts[1].id, for: .two)
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(model.layoutNames.name(.two) == "Layout 2")
        #expect(session.comparedLayouts(for: project.id).map(\.id) == [layouts[0].id, layouts[1].id])
        #expect(!model.isRunning)
        #expect(model.phase == .ready)

        service.releasePausedCall()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.floorPlan(for: .two)?.id == layouts[1].id)
        #expect(session.comparedLayouts(for: project.id).map(\.id) == [layouts[0].id, layouts[1].id])
        #expect(!model.isRunning)
        #expect(model.phase == .ready)
        #expect(session.savedAnalyses(for: project.id).count == 1)
    }

    @Test("Cached live rerun still reports to recordAnalysis")
    func cachedLiveRerunStillRecordsMatchedRun() async throws {
        let layouts = twoLayouts
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: layouts), for: project.id)
        var firstParams = TestLayouts.parameters
        firstParams.totalVisitors = 200
        var secondParams = firstParams
        secondParams.totalVisitors = 400
        session.setEventParameters(firstParams, for: project.id)

        let service = rankedService(for: layouts)
        let model = DashboardViewModel(
            projectID: project.id,
            session: session,
            analysisService: service,
            catalog: catalog
        )

        await model.runSimulation()
        let firstSaved = try #require(session.savedAnalyses(for: project.id).first)

        session.setEventParameters(secondParams, for: project.id)
        await model.runSimulation()
        let callsAfterSecondRun = service.calls.count
        #expect(session.savedAnalyses(for: project.id).count == 2)

        session.deleteSavedAnalysis(id: firstSaved.id, in: project.id)
        session.setEventParameters(firstParams, for: project.id)
        await model.runSimulation()

        #expect(model.phase == .ready)
        #expect(service.calls.count == callsAfterSecondRun)
        #expect(session.savedAnalyses(for: project.id).contains { $0.parameters == firstParams })
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
    private var shouldPauseNextCall = false
    private var hasEnteredPausedCall = false
    private var pausedCallStarted: CheckedContinuation<Void, Never>?
    private var pausedCallGate: CheckedContinuation<Void, Never>?
    private let makeAnalysis: ((Layout, EventParameters) -> LayoutAnalysis)?

    init(
        pausesFirstCall: Bool = false,
        makeAnalysis: ((Layout, EventParameters) -> LayoutAnalysis)? = nil
    ) {
        self.pausesFirstCall = pausesFirstCall
        self.makeAnalysis = makeAnalysis
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

    func pauseNextCall() {
        shouldPauseNextCall = true
        hasEnteredPausedCall = false
    }

    func waitForPausedCall() async {
        if hasEnteredPausedCall { return }
        await withCheckedContinuation { continuation in
            pausedCallStarted = continuation
        }
    }

    func releasePausedCall() {
        pausedCallGate?.resume()
        pausedCallGate = nil
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
        } else if shouldPauseNextCall {
            shouldPauseNextCall = false
            await withCheckedContinuation { continuation in
                pausedCallGate = continuation
                hasEnteredPausedCall = true
                pausedCallStarted?.resume()
                pausedCallStarted = nil
            }
        }
        guard !Task.isCancelled else { return [] }
        return layouts.map { layout in
            if let makeAnalysis { return makeAnalysis(layout, parameters) }
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

    @Test("A run cancelled before it starts leaves the live run to finish")
    func cancelledRunLeavesTheLiveOne() async {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(ProjectDraft(name: "P", layouts: [TestLayouts.hall(booths: 3)]), for: project.id)
        let service = GatedAnalysisService(pausesFirstCall: true)
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: service, catalog: catalog
        )
        let live = Task { await model.runSimulation() }
        await service.waitForFirstCall()

        let stale = Task { await model.runSimulation() }
        stale.cancel()
        await stale.value
        service.releaseFirstCall()
        await live.value

        #expect(model.phase == .ready)
        #expect(model.simulationResult != nil)
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

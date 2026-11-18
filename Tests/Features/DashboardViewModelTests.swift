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
        #expect(summary.stats.map(\.title) == ["Crowded Spots", "Time Stuck", "Crowd Level"])
        #expect(summary.stats.map(\.caption) == ["Stuck at once", "Total Duration", "Overall Condition"])
        #expect(summary.stats[2].text == (model.outcome(for: .one).worstSpot.grade.title))
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
        for tab in AnalysisTab.allCases {
            let content = try #require(model.content(for: tab))
            #expect(content.tiles.count == 2)
            #expect(content.series.allSatisfy { $0.points.count == result.sampleHours.count })
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

        model.choose(layouts[2].id, for: .two)
        #expect(model.phase == .loading)
        await untilReady(model)
        #expect(model.floorPlan(for: .one)?.id == layouts[0].id && model.floorPlan(for: .two)?.id == layouts[2].id)

        model.choose(layouts[0].id, for: .two)
        await untilReady(model)
        #expect(model.floorPlan(for: .one)?.id == layouts[2].id && model.floorPlan(for: .two)?.id == layouts[0].id)
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

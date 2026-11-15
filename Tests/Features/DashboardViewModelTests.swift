import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@Suite
struct DashboardViewModelTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
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
        #expect(summary.stats.map(\.caption) == ["Detected", "Total Duration", "Overall Condition"])
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

    @Test("startSimulationIfNeeded preserves ready state when inputs are unchanged")
    func startSimulationIfNeededPreservesReadyState() async {
        let model = makeModel(layouts: twoLayouts, parameters: TestLayouts.parameters)
        await model.runSimulation()
        let previousAnalyses = model.simulationResult?.analyses
        model.startSimulationIfNeeded()
        #expect(model.phase == .ready)
        #expect(model.simulationResult?.analyses == previousAnalyses)
    }
}

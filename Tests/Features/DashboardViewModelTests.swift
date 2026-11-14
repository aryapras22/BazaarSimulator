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

    @Test("A project with fewer than two layouts has nothing to compare")
    func needsTwoLayouts() async {
        let model = makeModel(layouts: [TestLayouts.hall()])
        await model.runSimulation()
        #expect(model.phase == .needsTwoLayouts(count: 1))
        #expect(model.simulationResult == nil)
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
    func fallsBackToDefaults() async {
        let model = makeModel(layouts: twoLayouts)
        await model.runSimulation()
        #expect(model.peakHourText == "14:00")
        #expect(model.simulationResult?.sampleHours == [10, 12, 14, 16, 18, 20, 21])
    }

    @Test("Applied parameters change the result")
    func parametersChangeResult() async throws {
        var quiet = TestLayouts.parameters
        quiet.totalVisitors = 100
        var busy = quiet
        busy.totalVisitors = 2500
        busy.peakPeriods = [TimeRange(startMinute: 11 * 60, endMinute: 12 * 60)]

        let quietModel = makeModel(layouts: twoLayouts, parameters: quiet)
        let busyModel = makeModel(layouts: twoLayouts, parameters: busy)
        await quietModel.runSimulation()
        await busyModel.runSimulation()

        #expect(busyModel.peakHourText == "11:00")
        #expect(quietModel.peakHourText == "12:50")
        let quietDensity = try #require(quietModel.simulationResult?.outcomes[.one]?.D)
        let busyDensity = try #require(busyModel.simulationResult?.outcomes[.one]?.D)
        #expect(busyDensity > quietDensity)
    }

    @Test("Closing the Parameters sheet dismisses it")
    func closingParameters() {
        let model = makeModel(layouts: twoLayouts, parameters: TestLayouts.parameters)
        model.isParametersPresented = true
        model.closeParameters()
        #expect(!model.isParametersPresented)
    }
}

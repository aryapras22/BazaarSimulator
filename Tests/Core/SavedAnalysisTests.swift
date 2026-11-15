import Foundation
import Testing
@testable import BazaarSimulator

@Suite("SavedAnalysisTests")
@MainActor
struct SavedAnalysisTests {
    /// Built once, so every run of a test sees the same layouts with the same IDs.
    private let fixedLayouts = [PreviewLayouts.annyeong(), PreviewLayouts.beyond()]

    private func layouts() -> [Layout] { fixedLayouts }

    private func analysis(for layout: Layout) -> LayoutAnalysis {
        let spot = SpotMeasurement(
            number: 1, name: "Near B-1", position: SIMD2(4, 5),
            densitySamples: [0.1, 0.4, 0.9, 0.5], peopleSamples: [1, 4, 9, 5]
        )
        var analysis = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [spot],
            flowPerMinute: [3, 4, 5], simulatedPeople: 120, totalPeople: 120
        )
        analysis.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        return analysis
    }

    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
    )

    private func parameters(visitors: Int = 500) -> EventParameters {
        catalog.defaultParameters().with(totalVisitors: visitors)
    }

    private func record(_ session: ProjectSession, _ projectID: UUID, visitors: Int = 500) -> SavedAnalysis? {
        let all = layouts()
        return session.recordAnalysis(
            layouts: all, analyses: all.map(analysis(for:)), parameters: parameters(visitors: visitors), peakMinute: 690, in: projectID
        )
    }

    private func temporaryStore() -> FileSavedAnalysisStore {
        FileSavedAnalysisStore(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("saved-analysis-tests-\(UUID().uuidString)"))
    }

    @Test("A finished analysis is saved under its project as the next run")
    func analysisIsSaved() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")

        let first = record(session, project.id)
        let second = record(session, project.id, visitors: 800)

        #expect(first?.name == "Run 1")
        #expect(second?.name == "Run 2")
        #expect(session.savedAnalyses(for: project.id).map(\.name) == ["Run 1", "Run 2"])
    }

    @Test("Running again with the same layouts and parameters saves nothing new")
    func unchangedRunIsNotSavedAgain() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")

        _ = record(session, project.id)
        let again = record(session, project.id)

        #expect(again == nil)
        #expect(session.savedAnalyses(for: project.id).count == 1)
    }

    @Test("Run numbers are not reused after a delete, and a blank name is ignored")
    func numbersAndRenames() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        let first = record(session, project.id)
        _ = record(session, project.id, visitors: 800)
        session.deleteSavedAnalysis(id: first!.id, in: project.id)
        let third = record(session, project.id, visitors: 900)

        #expect(third?.name == "Run 3")
        session.renameSavedAnalysis(id: third!.id, in: project.id, to: "  ")
        #expect(session.savedAnalysis(id: third!.id, in: project.id)?.name == "Run 3")
        session.renameSavedAnalysis(id: third!.id, in: project.id, to: "Peak day")
        #expect(session.savedAnalysis(id: third!.id, in: project.id)?.name == "Peak day")
    }

    @Test("Saved analyses and projects come back after the app is closed")
    func survivesRelaunch() {
        let store = temporaryStore()
        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        let saved = record(session, project.id)
        session.renameSavedAnalysis(id: saved!.id, in: project.id, to: "Peak day")

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        let restored = reopened.savedAnalyses(for: project.id)

        #expect(reopened.projects.map(\.id) == [project.id])
        #expect(restored.map(\.name) == ["Peak day"])
        #expect(restored.first?.analyses == saved?.analyses)
        #expect(restored.first?.parameters == saved?.parameters)
        #expect(restored.first?.layouts == saved?.layouts)
        #expect(restored.first?.peakMinute == 690)
    }

    @Test("A deleted analysis stays deleted after the app is closed")
    func deleteSurvivesRelaunch() {
        let store = temporaryStore()
        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        let saved = record(session, project.id)
        session.deleteSavedAnalysis(id: saved!.id, in: project.id)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        #expect(reopened.savedAnalyses(for: project.id).isEmpty)
    }

    @Test("A saved analysis rebuilds the compare page without simulating again")
    func compareResultFromSavedAnalysis() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        let saved = record(session, project.id)!

        let result = SimulationResult(saved: saved, visitorTypes: [])

        #expect(result?.outcomes.count == 2)
        #expect(result?.outcomes[.one]?.spots.count == 1)
        #expect(result?.replay(for: .one) == nil)
        #expect(result?.schedule.peakMinute == 690)
    }

    @Test("The analysis pipeline's measurements survive being stored")
    func measurementsRoundTrip() throws {
        let original = analysis(for: layouts()[0])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LayoutAnalysis.self, from: data)

        #expect(decoded == original)
        #expect(decoded.replay == nil)
    }
}

@Suite("DashboardSavedRunTests")
@MainActor
struct DashboardSavedRunTests {
    private let catalog = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
    )

    private func session() -> (ProjectSession, UUID) {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(
            ProjectDraft(name: "P", layouts: [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6)]),
            for: project.id
        )
        return (session, project.id)
    }

    private func model(_ session: ProjectSession, _ projectID: UUID, source: DashboardViewModel.Source = .latest)
        -> DashboardViewModel {
        DashboardViewModel(
            projectID: projectID, source: source, session: session,
            analysisService: AnalysisService(), catalog: catalog
        )
    }

    @Test("A finished analysis is saved, and opening the page again reuses it instead of simulating")
    func savesOnceAndReuses() async {
        let (session, projectID) = session()
        let first = model(session, projectID)
        await first.runSimulation()

        #expect(first.phase == .ready)
        #expect(session.savedAnalyses(for: projectID).count == 1)
        #expect(!session.isSimulating(projectID))

        let reopened = model(session, projectID)
        await reopened.runSimulation()
        #expect(reopened.phase == .ready)
        #expect(session.savedAnalyses(for: projectID).count == 1)
    }

    @Test("Changing the parameters and running again saves a second run")
    func changedParametersSaveANewRun() async {
        let (session, projectID) = session()
        await model(session, projectID).runSimulation()

        var changed = catalog.defaultParameters()
        changed.totalVisitors += 100
        session.setEventParameters(changed, for: projectID)
        await model(session, projectID).runSimulation()

        #expect(session.savedAnalyses(for: projectID).map(\.name) == ["Run 1", "Run 2"])
    }

    @Test("A real analysis is written to disk and comes back after a restart")
    func realAnalysisSurvivesRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("dash-store-\(UUID().uuidString)")
        let session = ProjectSession(store: FileSavedAnalysisStore(root: root))
        let project = session.createProject(named: "P")
        session.setDraft(
            ProjectDraft(name: "P", layouts: [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6)]),
            for: project.id
        )
        await model(session, project.id).runSimulation()
        #expect(session.savedAnalyses(for: project.id).count == 1)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: root))
        let restored = try #require(reopened.savedAnalyses(for: project.id).first)
        #expect(restored.analyses.count == 2)
        #expect(restored.analyses.allSatisfy { !$0.spots.isEmpty })
    }

    @Test("A saved run opens read-only from its stored data")
    func savedRunIsReadOnly() async {
        let (session, projectID) = session()
        await model(session, projectID).runSimulation()
        let saved = session.savedAnalyses(for: projectID)[0]

        let opened = model(session, projectID, source: .saved(saved.id))
        await opened.runSimulation()

        #expect(opened.phase == .ready)
        #expect(!opened.canEdit)
        #expect(opened.title == "P · Run 1")
        #expect(session.savedAnalyses(for: projectID).count == 1)
    }
}

private extension EventParameters {
    func with(totalVisitors: Int) -> EventParameters {
        var copy = self
        copy.totalVisitors = totalVisitors
        return copy
    }
}

@Suite("SingleLayoutSavedRunTests")
@MainActor
struct SingleLayoutSavedRunTests {
    @Test("A saved run with one layout opens on its own")
    func savedOneLayout() {
        let layout = PreviewLayouts.annyeong()
        let spot = SpotMeasurement(
            number: 1, name: "Near B-1", position: SIMD2(4, 5),
            densitySamples: [0.1, 0.4, 0.9, 0.5], peopleSamples: [1, 4, 9, 5]
        )
        var measured = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [spot],
            flowPerMinute: [3, 4, 5], simulatedPeople: 120, totalPeople: 120
        )
        measured.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        let catalog = PresetCatalog(
            visitorTypes: TestLayouts.visitorTypes,
            bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
        )
        let saved = SavedAnalysis(
            number: 1, parameters: catalog.defaultParameters(), layouts: [layout], analyses: [measured], peakMinute: 690
        )

        let result = SimulationResult(saved: saved, visitorTypes: [])

        #expect(result?.layouts.count == 1)
        #expect(result?.outcomes[.one]?.spots.count == 1)
        #expect(result?.outcomes[.two] == nil)
    }
}

@Suite("SavedRunSimulatorTests")
@MainActor
struct SavedRunSimulatorTests {
    @Test("A saved run's simulator plays the run's own layout and parameters, not the project's now")
    func playsTheSavedLayout() async throws {
        let catalog = PresetCatalog(
            visitorTypes: TestLayouts.visitorTypes,
            bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
        )
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let savedLayout = TestLayouts.hall(booths: 3)
        let currentLayout = TestLayouts.hall(booths: 6)
        session.setDraft(ProjectDraft(name: "P", layouts: [currentLayout]), for: project.id)
        let stored = LayoutAnalysis(
            layoutID: savedLayout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [],
            flowPerMinute: [], simulatedPeople: 0, totalPeople: 0
        )
        let saved = SavedAnalysis(
            number: 1, parameters: catalog.defaultParameters(), layouts: [savedLayout], analyses: [stored], peakMinute: 840
        )
        // Stored the way the sidebar keeps it.
        session.recordAnalysis(
            layouts: saved.layouts, analyses: saved.analyses, parameters: saved.parameters,
            peakMinute: saved.peakMinute, in: project.id
        )
        let runID = try #require(session.savedAnalyses(for: project.id).first?.id)

        let model = SimulationPlayerViewModel(
            projectID: project.id, layoutID: .one, analysisID: runID, session: session,
            analysisService: AnalysisService(), catalog: catalog
        )
        await model.load()

        #expect(model.phase == .ready)
        #expect(model.layout?.id == savedLayout.id)
        #expect(model.layout?.id != currentLayout.id)
    }
}

@Suite("DashboardStaysOnAnalysisTests")
@MainActor
struct DashboardStaysOnAnalysisTests {
    @Test("Coming back to the page keeps the analysis on screen instead of running it again")
    func staysOnTheAnalysis() async throws {
        let catalog = PresetCatalog(
            visitorTypes: TestLayouts.visitorTypes,
            bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
        )
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        session.setDraft(
            ProjectDraft(name: "P", layouts: [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 6)]),
            for: project.id
        )
        let model = DashboardViewModel(
            projectID: project.id, session: session, analysisService: AnalysisService(), catalog: catalog
        )
        await model.runSimulation()
        #expect(model.phase == .ready)

        // The saved run is gone, which is when the page used to start over every time it was shown again.
        for run in session.savedAnalyses(for: project.id) { session.deleteSavedAnalysis(id: run.id, in: project.id) }
        model.startSimulation()
        try await Task.sleep(for: .milliseconds(300))

        #expect(model.phase == .ready)
        #expect(!model.isRunning)
        #expect(model.simulationResult != nil)
    }
}

@Suite("SavedRunPageTests")
@MainActor
struct SavedRunPageTests {
    private func savedRun() -> (ProjectSession, UUID, UUID) {
        let session = ProjectSession()
        let project = session.createProject(named: "P")
        let layout = PreviewLayouts.annyeong()
        let spot = SpotMeasurement(
            number: 1, name: "Near B-1", position: SIMD2(4, 5),
            densitySamples: [0.1, 0.4, 0.9, 0.5], peopleSamples: [1, 4, 9, 5]
        )
        var measured = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [spot],
            flowPerMinute: [3, 4, 5], simulatedPeople: 120, totalPeople: 120
        )
        measured.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        let catalog = PresetCatalog(
            visitorTypes: TestLayouts.visitorTypes,
            bazaarTypes: [BazaarTypePreset(id: "test", name: "Test", totalVisitors: 150, mix: ["a": 50, "b": 50])]
        )
        session.recordAnalysis(
            layouts: [layout], analyses: [measured], parameters: catalog.defaultParameters(),
            peakMinute: 690, in: project.id
        )
        return (session, project.id, session.savedAnalyses(for: project.id)[0].id)
    }

    @Test("A saved run's page shows its result from the start, with no loading page")
    func readyFromTheStart() {
        let (session, projectID, runID) = savedRun()
        let model = DashboardViewModel(
            projectID: projectID, source: .saved(runID), session: session,
            analysisService: AnalysisService(),
            catalog: PresetCatalog(visitorTypes: TestLayouts.visitorTypes, bazaarTypes: [])
        )

        #expect(model.phase == .ready)
        #expect(model.simulationResult != nil)
    }

    @Test("The factory gives the same page for the same saved run, so a refresh cannot reset it to loading")
    func sameViewModelEveryTime() {
        let (session, projectID, runID) = savedRun()
        let services = AppServices(projectSession: session)
        let factory = ProjectScreenFactory(services: services, router: AppRouter())

        let first = factory.makeSavedDashboardViewModel(projectID: projectID, analysisID: runID)
        let second = factory.makeSavedDashboardViewModel(projectID: projectID, analysisID: runID)

        #expect(first === second)
        #expect(first.phase == .ready)
    }
}

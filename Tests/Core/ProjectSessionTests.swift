import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ProjectSessionTests")
@MainActor
struct ProjectSessionTests {
    @Test("Created projects keep their order")
    func createdProjectsKeepOrder() {
        let session = ProjectSession()
        session.createProject(named: "Alpha")
        session.createProject(named: "Beta")
        session.createProject(named: "Gamma")

        #expect(session.projects.map(\.name) == ["Alpha", "Beta", "Gamma"])
    }

    @Test("Selecting an unknown ID changes nothing")
    func selectingUnknownIDChangesNothing() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        session.selectProject(id: project.id)

        session.selectProject(id: UUID())

        #expect(session.activeProjectID == project.id)
    }

    @Test("Renaming updates only the matching project")
    func renamingUpdatesOnlyMatchingProject() {
        let session = ProjectSession()
        let first = session.createProject(named: "First")
        let second = session.createProject(named: "Second")

        session.renameProject(id: first.id, to: "Updated First")

        #expect(session.projects.first { $0.id == first.id }?.name == "Updated First")
        #expect(session.projects.first { $0.id == second.id }?.name == "Second")
    }

    @Test("Drafts are stored per project")
    func draftsStoredPerProject() {
        let session = ProjectSession()
        let first = session.createProject(named: "First")
        let second = session.createProject(named: "Second")

        let draftA = ProjectDraft(name: "Draft A")
        let draftB = ProjectDraft(name: "Draft B")

        session.setDraft(draftA, for: first.id)
        session.setDraft(draftB, for: second.id)

        #expect(session.draft(for: first.id)?.name == "Draft A")
        #expect(session.draft(for: second.id)?.name == "Draft B")
    }

    private func temporaryStore() -> FileSavedAnalysisStore {
        FileSavedAnalysisStore(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("project-session-tests-\(UUID().uuidString)"))
    }

    private func customEventParameters() -> EventParameters {
        EventParameters(
            totalVisitors: 1_250,
            eventHours: TimeRange(startMinute: 9 * 60, endMinute: 18 * 60),
            peakPeriods: [TimeRange(startMinute: 12 * 60, endMinute: 14 * 60)],
            bazaarTypeID: "night-market",
            mix: VisitorMix(shares: [
                VisitorMix.Share(id: "socializer", percent: 30),
                VisitorMix.Share(id: "family", percent: 25),
                VisitorMix.Share(id: "explorer", percent: 20),
                VisitorMix.Share(id: "buyer", percent: 25)
            ])
        )
    }

    private func expectedModalParameters() -> ModalParameters {
        ModalParameters(
            totalVisitors: 1_250,
            startMinutes: 9 * 60,
            endMinutes: 18 * 60,
            bazaarType: "night-market",
            socializerPercent: 30,
            familyMemberPercent: 25,
            explorerPercent: 20,
            purposeBuyerPercent: 25
        )
    }

    private func writeStateJSON<Value: Encodable>(
        _ value: Value, for projectID: UUID, in store: FileSavedAnalysisStore
    ) throws {
        let stateDirectory = store.rootForTesting.appendingPathComponent("State", isDirectory: true)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: stateDirectory.appendingPathComponent("\(projectID.uuidString).json"))
    }

    @Test("Event parameters, synced modal parameters, and compared layouts survive a relaunch")
    func persistsEventParametersAndComparedLayoutsAcrossRelaunch() {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        let first = TestLayouts.hall(booths: 3)
        let second = TestLayouts.hall(booths: 4)
        let third = TestLayouts.hall(booths: 5)
        session.setDraft(ProjectDraft(name: "Alpha", layouts: [first, second, third]), for: project.id)

        let parameters = customEventParameters()
        session.setEventParameters(parameters, for: project.id)
        session.setComparedLayout(third.id, at: 0, for: project.id)
        session.setComparedLayout(first.id, at: 1, for: project.id)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))

        #expect(reopened.eventParameters(for: project.id) == parameters)
        #expect(reopened.parameters(for: project.id) == expectedModalParameters())
        #expect(reopened.comparedLayouts(for: project.id).map(\.id) == [third.id, first.id])
    }

    @Test("Legacy stores without state files and partial state JSON fall back to default parameters and layouts")
    func loadsLegacyStoreAndPartialStateWithFallbackDefaults() throws {
        struct ComparedOnlyState: Encodable {
            let comparedLayoutIDs: [Layout.ID]
        }
        struct ParametersOnlyState: Encodable {
            let eventParameters: EventParameters
        }

        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let legacy = ProjectSummary(name: "Legacy")
        let comparedOnly = ProjectSummary(name: "ComparedOnly")
        let parametersOnly = ProjectSummary(name: "ParametersOnly")
        let first = TestLayouts.hall(booths: 3)
        let second = TestLayouts.hall(booths: 4)
        let third = TestLayouts.hall(booths: 5)
        let parameters = customEventParameters()

        store.saveProjects([legacy, comparedOnly, parametersOnly])
        store.saveDraft(ProjectDraft(name: legacy.name, layouts: [first, second, third]), for: legacy.id)
        store.saveDraft(ProjectDraft(name: comparedOnly.name, layouts: [first, second, third]), for: comparedOnly.id)
        store.saveDraft(
            ProjectDraft(name: parametersOnly.name, layouts: [first, second, third]), for: parametersOnly.id
        )
        try writeStateJSON(ComparedOnlyState(comparedLayoutIDs: [third.id, first.id]), for: comparedOnly.id, in: store)
        try writeStateJSON(ParametersOnlyState(eventParameters: parameters), for: parametersOnly.id, in: store)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))

        #expect(reopened.eventParameters(for: legacy.id) == nil)
        #expect(reopened.parameters(for: legacy.id) == ModalParameters())
        #expect(reopened.comparedLayouts(for: legacy.id).map(\.id) == [first.id, second.id])

        #expect(reopened.eventParameters(for: comparedOnly.id) == nil)
        #expect(reopened.parameters(for: comparedOnly.id) == ModalParameters())
        #expect(reopened.comparedLayouts(for: comparedOnly.id).map(\.id) == [third.id, first.id])

        #expect(reopened.eventParameters(for: parametersOnly.id) == parameters)
        #expect(reopened.parameters(for: parametersOnly.id) == expectedModalParameters())
        #expect(reopened.comparedLayouts(for: parametersOnly.id).map(\.id) == [first.id, second.id])
    }

    @Test("Deleting a project removes its persisted session state so a relaunch does not resurrect it")
    func deletingProjectRemovesPersistedState() {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Drop")
        let first = TestLayouts.hall(booths: 3)
        let second = TestLayouts.hall(booths: 4)
        let third = TestLayouts.hall(booths: 5)
        let draft = ProjectDraft(name: "Drop", layouts: [first, second, third])
        let parameters = customEventParameters()

        session.setDraft(draft, for: project.id)
        session.setEventParameters(parameters, for: project.id)
        session.setComparedLayout(third.id, at: 0, for: project.id)

        let beforeDelete = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        #expect(beforeDelete.eventParameters(for: project.id) == parameters)
        #expect(beforeDelete.comparedLayouts(for: project.id).map(\.id) == [third.id, second.id])

        session.deleteProject(id: project.id)
        store.saveProjects([project])
        store.saveDraft(draft, for: project.id)

        let afterDelete = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        #expect(afterDelete.eventParameters(for: project.id) == nil)
        #expect(afterDelete.parameters(for: project.id) == ModalParameters())
        #expect(afterDelete.comparedLayouts(for: project.id).map(\.id) == [first.id, second.id])
    }
}

@Suite("LatestDisplayedAnalysisTests")
@MainActor
struct LatestDisplayedAnalysisTests {
    private struct PersistedLatestAnalysisState: Decodable {
        let latestDisplayedAnalysisID: SavedAnalysis.ID?
    }

    private struct LegacySessionState: Encodable {
        let eventParameters: EventParameters
        let comparedLayoutIDs: [Layout.ID]
    }

    private func temporaryStore() -> FileSavedAnalysisStore {
        FileSavedAnalysisStore(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("project-session-latest-run-\(UUID().uuidString)"))
    }

    private func parameters(visitors: Int) -> EventParameters {
        var copy = TestLayouts.parameters
        copy.totalVisitors = visitors
        return copy
    }

    private func analysis(for layout: Layout) -> LayoutAnalysis {
        let spot = SpotMeasurement(
            number: 1, name: "Near B1", position: SIMD2(4, 5),
            densitySamples: [0.25, 0.5], peopleSamples: [2, 5]
        )
        var measured = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 60, spots: [spot],
            flowPerMinute: [2, 3], simulatedPeople: 40, totalPeople: 40
        )
        measured.plan = PlanFrame(origin: .zero, size: layout.sizeM)
        return measured
    }

    private func persistedLatestDisplayedAnalysisID(
        for projectID: UUID, in store: FileSavedAnalysisStore
    ) -> SavedAnalysis.ID? {
        let stateFile = store.rootForTesting
            .appendingPathComponent("State", isDirectory: true)
            .appendingPathComponent("\(projectID.uuidString).json")
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(PersistedLatestAnalysisState.self, from: data))?.latestDisplayedAnalysisID
    }

    private func writeStateJSON<Value: Encodable>(
        _ value: Value, for projectID: UUID, in store: FileSavedAnalysisStore
    ) throws {
        let stateDirectory = store.rootForTesting.appendingPathComponent("State", isDirectory: true)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: stateDirectory.appendingPathComponent("\(projectID.uuidString).json"))
    }

    private func makeViewModel(session: ProjectSession, projectID: UUID) -> ProjectLibraryViewModel {
        ProjectLibraryViewModel(
            session: session, destination: { .analysis(projectID: projectID) }, onOpenProject: { _ in }
        )
    }

    @Test("Recording a new analysis tracks and persists it as the latest displayed run")
    func recordingNewRunTracksAndPersistsLatestDisplayedRun() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let analyses = layouts.map(analysis(for:))
        let viewModel = makeViewModel(session: session, projectID: project.id)

        let run1 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        ))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == run1.id)
        #expect(viewModel.isAnalysisSelected(run1, in: project))

        let run2 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 600), peakMinute: 690, in: project.id
        ))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == run2.id)
        #expect(viewModel.isAnalysisSelected(run2, in: project))
        #expect(!viewModel.isAnalysisSelected(run1, in: project))
    }

    @Test("Matching an earlier run switches the latest displayed run back without saving a duplicate")
    func matchingEarlierRunSwitchesLatestDisplayedRunWithoutDuplicate() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let reversed = [layouts[1], layouts[0]]
        let analyses = layouts.map(analysis(for:))
        let viewModel = makeViewModel(session: session, projectID: project.id)

        let run1 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        ))
        let run2 = try #require(session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 600), peakMinute: 690, in: project.id
        ))

        let duplicate = session.recordAnalysis(
            layouts: reversed,
            analyses: reversed.map(analysis(for:)),
            parameters: parameters(visitors: 300),
            peakMinute: 660,
            in: project.id
        )

        #expect(duplicate == nil)
        #expect(session.savedAnalyses(for: project.id).map(\.id) == [run1.id, run2.id])
        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == run1.id)
    }

    @Test("Latest displayed analysis selection survives relaunch through FileSavedAnalysisStore")
    func latestDisplayedAnalysisSurvivesRelaunch() {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let project = ProjectSummary(name: "Alpha")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let analyses = layouts.map(analysis(for:))
        let run1 = SavedAnalysis(
            number: 1, createdAt: Date(timeIntervalSince1970: 1_000),
            parameters: parameters(visitors: 300), layouts: layouts, analyses: analyses, peakMinute: 660
        )
        let run2 = SavedAnalysis(
            number: 2, createdAt: Date(timeIntervalSince1970: 2_000),
            parameters: parameters(visitors: 600), layouts: layouts, analyses: analyses, peakMinute: 690
        )
        store.saveProjects([project])
        store.save(run1, in: project.id)
        store.save(run2, in: project.id)

        let session = ProjectSession(store: store)
        let matched = session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        )
        #expect(matched == nil)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        let viewModel = makeViewModel(session: reopened, projectID: project.id)

        #expect(reopened.savedAnalyses(for: project.id).map(\.id) == [run1.id, run2.id])
        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))
    }

    @Test("Legacy state files without latestDisplayedAnalysisID fall back to the newest run and persist updates")
    func legacyStateWithoutLatestDisplayedAnalysisFallsBackToNewestRun() throws {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let project = ProjectSummary(name: "Legacy")
        let first = TestLayouts.hall(booths: 3)
        let second = TestLayouts.hall(booths: 4)
        let third = TestLayouts.hall(booths: 5)
        let params1 = parameters(visitors: 300)
        let pair = [first, second]
        let analyses = pair.map(analysis(for:))
        let run1 = SavedAnalysis(
            number: 1, createdAt: Date(timeIntervalSince1970: 1_000),
            parameters: params1, layouts: pair, analyses: analyses, peakMinute: 660
        )
        let run2 = SavedAnalysis(
            number: 2, createdAt: Date(timeIntervalSince1970: 2_000),
            parameters: parameters(visitors: 600), layouts: pair, analyses: analyses, peakMinute: 690
        )

        store.saveProjects([project])
        store.saveDraft(ProjectDraft(name: project.name, layouts: [first, second, third]), for: project.id)
        try writeStateJSON(
            LegacySessionState(eventParameters: params1, comparedLayoutIDs: [third.id, first.id]),
            for: project.id, in: store
        )
        store.save(run1, in: project.id)
        store.save(run2, in: project.id)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        let viewModel = makeViewModel(session: reopened, projectID: project.id)

        #expect(reopened.eventParameters(for: project.id) == params1)
        #expect(reopened.comparedLayouts(for: project.id).map(\.id) == [third.id, first.id])
        #expect(viewModel.isAnalysisSelected(run2, in: project))
        #expect(!viewModel.isAnalysisSelected(run1, in: project))

        let matched = reopened.recordAnalysis(
            layouts: run1.layouts, analyses: run1.analyses,
            parameters: run1.parameters, peakMinute: run1.peakMinute, in: project.id
        )

        #expect(matched == nil)
        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == run1.id)
        #expect(reopened.eventParameters(for: project.id) == params1)
        #expect(reopened.comparedLayouts(for: project.id).map(\.id) == [third.id, first.id])
    }

    @Test("Deleting the tracked displayed run falls back to the newest remaining run and clears persisted ID")
    func deletingTrackedDisplayedRunFallsBackToNewestRemainingRun() {
        let store = temporaryStore()
        defer { try? FileManager.default.removeItem(at: store.rootForTesting) }

        let project = ProjectSummary(name: "Alpha")
        let layouts = [TestLayouts.hall(booths: 3), TestLayouts.hall(booths: 5)]
        let analyses = layouts.map(analysis(for:))
        let run1 = SavedAnalysis(
            number: 1, createdAt: Date(timeIntervalSince1970: 1_000),
            parameters: parameters(visitors: 300), layouts: layouts, analyses: analyses, peakMinute: 660
        )
        let run2 = SavedAnalysis(
            number: 2, createdAt: Date(timeIntervalSince1970: 2_000),
            parameters: parameters(visitors: 600), layouts: layouts, analyses: analyses, peakMinute: 690
        )
        let run3 = SavedAnalysis(
            number: 3, createdAt: Date(timeIntervalSince1970: 3_000),
            parameters: parameters(visitors: 900), layouts: layouts, analyses: analyses, peakMinute: 720
        )
        store.saveProjects([project])
        store.save(run1, in: project.id)
        store.save(run2, in: project.id)
        store.save(run3, in: project.id)

        let session = ProjectSession(store: store)
        let viewModel = makeViewModel(session: session, projectID: project.id)
        _ = session.recordAnalysis(
            layouts: layouts, analyses: analyses, parameters: parameters(visitors: 300), peakMinute: 660, in: project.id
        )

        #expect(viewModel.isAnalysisSelected(run1, in: project))
        #expect(!viewModel.isAnalysisSelected(run3, in: project))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == run1.id)

        session.deleteSavedAnalysis(id: run1.id, in: project.id)

        #expect(viewModel.isAnalysisSelected(run3, in: project))
        #expect(!viewModel.isAnalysisSelected(run2, in: project))
        #expect(persistedLatestDisplayedAnalysisID(for: project.id, in: store) == nil)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        let reopenedViewModel = makeViewModel(session: reopened, projectID: project.id)
        #expect(reopened.savedAnalyses(for: project.id).map(\.id) == [run2.id, run3.id])
        #expect(reopenedViewModel.isAnalysisSelected(run3, in: project))
        #expect(!reopenedViewModel.isAnalysisSelected(run2, in: project))
    }
}

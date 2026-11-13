import Foundation
import Testing
@testable import BazaarSimulator

@Suite("SavedAnalysisTests")
@MainActor
struct SavedAnalysisTests {
    private func shortParameters() -> EventParameters {
        var parameters = EventParameters()
        parameters.totalVisitors = 20
        parameters.startMinutes = 10 * 60
        parameters.endMinutes = 10 * 60 + 15
        return parameters
    }

    private func finishRun(_ session: ProjectSession, _ projectID: UUID) async {
        session.runSimulations(for: projectID)
        while session.isSimulating(projectID) { try? await Task.sleep(for: .milliseconds(50)) }
    }

    private func sessionWithFinishedRun(store: (any SavedAnalysisStoring)? = nil) async -> (ProjectSession, UUID) {
        let session = ProjectSession(store: store)
        let project = session.createProject(named: "Alpha")
        session.setDraft(
            ProjectDraft(name: "Alpha", legend: Legend(), layouts: [PreviewLayouts.annyeong()]),
            for: project.id
        )
        session.setParameters(shortParameters(), for: project.id)
        await finishRun(session, project.id)
        return (session, project.id)
    }

    private func temporaryStore() -> FileSavedAnalysisStore {
        FileSavedAnalysisStore(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("saved-analysis-tests-\(UUID().uuidString)"))
    }

    @Test("A finished parameter run is saved under its project with its measurements")
    func finishedRunIsSaved() async {
        let (session, projectID) = await sessionWithFinishedRun()

        let saved = session.savedAnalyses(for: projectID)
        #expect(saved.map(\.name) == ["Run 1"])
        #expect(saved.first?.parameters.totalVisitors == 20)
        #expect(saved.first?.measurements.count == 1)
        #expect(saved.first?.measurements.first?.layoutID == saved.first?.layouts.first?.id)
    }

    @Test("Each run is saved on its own and run numbers are not reused after a delete")
    func runsAccumulate() async {
        let (session, projectID) = await sessionWithFinishedRun()
        await finishRun(session, projectID)
        session.deleteSavedAnalysis(id: session.savedAnalyses(for: projectID)[0].id, in: projectID)
        await finishRun(session, projectID)

        #expect(session.savedAnalyses(for: projectID).map(\.name) == ["Run 2", "Run 3"])
    }

    @Test("Renaming keeps the old name when the new one is blank")
    func renameIgnoresBlank() async {
        let (session, projectID) = await sessionWithFinishedRun()
        let saved = session.savedAnalyses(for: projectID)[0]

        session.renameSavedAnalysis(id: saved.id, in: projectID, to: "  ")
        #expect(session.savedAnalysis(id: saved.id, in: projectID)?.name == "Run 1")

        session.renameSavedAnalysis(id: saved.id, in: projectID, to: "Peak day")
        #expect(session.savedAnalysis(id: saved.id, in: projectID)?.name == "Peak day")
    }

    @Test("Saved analyses and projects come back after the app is closed")
    func survivesRelaunch() async {
        let store = temporaryStore()
        let (session, projectID) = await sessionWithFinishedRun(store: store)
        let saved = session.savedAnalyses(for: projectID)[0]
        session.renameSavedAnalysis(id: saved.id, in: projectID, to: "Peak day")

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        #expect(reopened.projects.map(\.id) == [projectID])
        let restored = reopened.savedAnalyses(for: projectID)
        #expect(restored.map(\.name) == ["Peak day"])
        #expect(restored.first?.measurements == saved.measurements)
        #expect(restored.first?.parameters == saved.parameters)
        #expect(restored.first?.layouts == saved.layouts)
    }

    @Test("A deleted analysis stays deleted after the app is closed")
    func deleteSurvivesRelaunch() async {
        let store = temporaryStore()
        let (session, projectID) = await sessionWithFinishedRun(store: store)
        session.deleteSavedAnalysis(id: session.savedAnalyses(for: projectID)[0].id, in: projectID)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: store.rootForTesting))
        #expect(reopened.savedAnalyses(for: projectID).isEmpty)
    }

    @Test("Opening a saved analysis builds the compare page from its stored measurements")
    func compareResultFromSavedAnalysis() async {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        session.setDraft(
            ProjectDraft(
                name: "Alpha", legend: Legend(),
                layouts: [PreviewLayouts.annyeong(), PreviewLayouts.beyond()]
            ),
            for: project.id
        )
        session.setParameters(shortParameters(), for: project.id)
        await finishRun(session, project.id)

        let analysis = session.savedAnalyses(for: project.id)[0]
        let result = CompareResult(analysis: analysis)
        #expect(result?.outcomes.count == 2)
        #expect(result?.schedule.startHour == 10)
    }
}

@Suite("ProjectLibrarySelectionTests")
@MainActor
struct ProjectLibrarySelectionTests {
    @Test("Opening a project folder goes to its setup page, not its analysis")
    func folderOpensSetup() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        let router = AppRouter()
        var opened: UUID?
        let viewModel = ProjectLibraryViewModel(
            session: session,
            destination: { router.destination },
            onOpenProject: { opened = $0; router.showSetup(projectID: $0) }
        )

        viewModel.selectProject(project)

        #expect(opened == project.id)
        #expect(router.destination == .setup(projectID: project.id))
        #expect(viewModel.isFolderSelected(project))
    }

    @Test("The folder is not highlighted while its analysis page is open")
    func folderNotSelectedOnAnalysis() {
        let session = ProjectSession()
        let project = session.createProject(named: "Alpha")
        let router = AppRouter(destination: .analysis(projectID: project.id))
        let viewModel = ProjectLibraryViewModel(
            session: session, destination: { router.destination }, onOpenProject: { _ in }
        )

        #expect(!viewModel.isFolderSelected(project))
    }
}

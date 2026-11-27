import Foundation
import Testing
@testable import BazaarSimulator

@MainActor
@discardableResult
private func recordRun(_ session: ProjectSession, in projectID: UUID) -> SavedAnalysis? {
    let layout = PreviewLayouts.annyeong()
    let measured = LayoutAnalysis(
        layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [],
        flowPerMinute: [], simulatedPeople: 10, totalPeople: 10
    )
    let parameters = PresetCatalog(
        visitorTypes: TestLayouts.visitorTypes,
        bazaarTypes: [BazaarTypePreset(id: "t", name: "T", mix: ["a": 50, "b": 50])],
        defaultTotalVisitors: 100
    ).defaultParameters()
    return session.recordAnalysis(
        layouts: [layout], analyses: [measured], parameters: parameters, peakMinute: 700, in: projectID
    )
}

@Suite("ProjectDeletionTests")
@MainActor
struct ProjectDeletionTests {
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("deletion-tests-\(UUID().uuidString)")
    }

    @Test("Deleting a project removes it with its layouts, its saved analyses, and its place as the active project")
    func sessionDropsEverythingOfTheProject() {
        let session = ProjectSession()
        let keep = session.createProject(named: "Keep")
        let drop = session.createProject(named: "Drop")
        for project in [keep, drop] {
            session.setDraft(ProjectDraft(name: project.name, layouts: [PreviewLayouts.annyeong()]), for: project.id)
            recordRun(session, in: project.id)
        }
        session.selectProject(id: drop.id)

        session.deleteProject(id: drop.id)

        #expect(session.projects.map(\.name) == ["Keep"])
        #expect(session.activeProjectID == nil)
        #expect(session.draft(for: drop.id) == nil)
        #expect(session.savedAnalyses(for: drop.id).isEmpty)
        #expect(session.draft(for: keep.id) != nil)
        #expect(session.savedAnalyses(for: keep.id).count == 1)
    }

    @Test("Deleting a project that does not exist changes nothing")
    func unknownProject() {
        let session = ProjectSession()
        session.createProject(named: "Keep")
        session.deleteProject(id: UUID())
        #expect(session.projects.count == 1)
    }

    @Test("A deleted project and its analyses are gone after the app is closed")
    func deletionSurvivesRestart() {
        let root = temporaryRoot()
        let session = ProjectSession(store: FileSavedAnalysisStore(root: root))
        let keep = session.createProject(named: "Keep")
        let drop = session.createProject(named: "Drop")
        recordRun(session, in: keep.id)
        recordRun(session, in: drop.id)

        session.deleteProject(id: drop.id)

        let reopened = ProjectSession(store: FileSavedAnalysisStore(root: root))
        #expect(reopened.projects.map(\.name) == ["Keep"])
        #expect(reopened.savedAnalyses(for: keep.id).count == 1)
        #expect(reopened.savedAnalyses(for: drop.id).isEmpty)
    }

    @Test("Renaming a project changes the name the sidebar lists, and keeps it after a restart")
    func renameFollowsInTheSidebar() {
        let root = temporaryRoot()
        let session = ProjectSession(store: FileSavedAnalysisStore(root: root))
        let project = session.createProject(named: "Untitled")
        let library = ProjectLibraryViewModel(session: session, onOpenProject: { _ in })
        let setup = ProjectSetupViewModel(
            projectID: project.id, session: session, importQueue: ScriptedImportQueue(), onContinue: { _ in }
        )

        setup.projectName = "Basha Vol. 1"

        #expect(library.projects.map(\.name) == ["Basha Vol. 1"])
        #expect(ProjectSession(store: FileSavedAnalysisStore(root: root)).projects.map(\.name) == ["Basha Vol. 1"])
    }
}

@Suite("SidebarDeletionTests")
@MainActor
struct SidebarDeletionTests {
    private func library(
        deleted: @escaping (UUID) -> Void = { _ in }
    ) -> (ProjectLibraryViewModel, ProjectSession, ProjectSummary) {
        let session = ProjectSession()
        let project = session.createProject(named: "Basha Vol. 1")
        let model = ProjectLibraryViewModel(session: session, onOpenProject: { _ in }, onDeleteProject: deleted)
        return (model, session, project)
    }

    @Test("Asking to delete a project only asks the question, and cancelling leaves it alone")
    func askingDoesNotDelete() {
        var deleted: [UUID] = []
        let (model, _, project) = library { deleted.append($0) }

        model.requestDeletion(of: project)
        #expect(model.pendingDeletion?.title == "Delete Project?")
        #expect(model.pendingDeletion?.message == "Deleting “Basha Vol. 1” will also remove its data.")

        model.cancelDeletion()
        #expect(model.pendingDeletion == nil)
        #expect(deleted.isEmpty)
    }

    @Test("Confirming hands the project to be deleted")
    func confirmingDeletes() {
        var deleted: [UUID] = []
        let (model, _, project) = library { deleted.append($0) }

        model.requestDeletion(of: project)
        model.confirmDeletion()

        #expect(deleted == [project.id])
        #expect(model.pendingDeletion == nil)
    }

    @Test("Confirming with nothing asked deletes nothing")
    func nothingPending() {
        var deleted: [UUID] = []
        let (model, _, _) = library { deleted.append($0) }
        model.confirmDeletion()
        #expect(deleted.isEmpty)
    }

    @Test("An analysis is deleted from the sidebar the same way, after a question")
    func analysisDeletion() {
        let (model, session, project) = library()
        let layout = PreviewLayouts.annyeong()
        let measured = LayoutAnalysis(
            layoutID: layout.id, eventStartMinute: 600, sampleIntervalSeconds: 15, spots: [],
            flowPerMinute: [], simulatedPeople: 1, totalPeople: 1
        )
        let parameters = PresetCatalog(
            visitorTypes: TestLayouts.visitorTypes,
            bazaarTypes: [BazaarTypePreset(id: "t", name: "T", mix: ["a": 50, "b": 50])],
            defaultTotalVisitors: 100
        ).defaultParameters()
        let run = session.recordAnalysis(
            layouts: [layout], analyses: [measured], parameters: parameters, peakMinute: 700, in: project.id
        )!

        model.requestDeletion(of: run, in: project)
        #expect(model.pendingDeletion?.title == "Delete Analysis?")
        #expect(session.savedAnalyses(for: project.id).count == 1)

        model.confirmDeletion()
        #expect(session.savedAnalyses(for: project.id).isEmpty)
    }

    @Test("Deleting the open project moves on to the next one, and to the empty workspace after the last")
    func factoryMovesOn() {
        let session = ProjectSession()
        let first = session.createProject(named: "First")
        let second = session.createProject(named: "Second")
        let services = AppServices(projectSession: session)
        let router = AppRouter(destination: .setup(projectID: first.id))
        let factory = ProjectScreenFactory(services: services, router: router)
        let library = factory.makeLibraryViewModel()

        library.requestDeletion(of: first)
        library.confirmDeletion()
        #expect(session.projects.map(\.id) == [second.id])
        #expect(router.destination == .setup(projectID: second.id))

        library.requestDeletion(of: second)
        library.confirmDeletion()
        #expect(session.projects.isEmpty)
        #expect(router.destination == .empty)
    }

    @Test("Deleting a saved run while its replay is open leaves the replay")
    func deletingTheReplayedRunLeavesIt() {
        let session = ProjectSession()
        let project = session.createProject(named: "First")
        let run = recordRun(session, in: project.id)!
        let router = AppRouter(destination: .simulation(projectID: project.id, layout: .one, analysisID: run.id))
        let factory = ProjectScreenFactory(services: AppServices(projectSession: session), router: router)
        let library = factory.makeLibraryViewModel()

        library.requestDeletion(of: run, in: project)
        library.confirmDeletion()

        #expect(router.destination == .setup(projectID: project.id))
    }

    @Test("Deleting a saved run drops its cached page")
    func deletingARunDropsItsPage() {
        let session = ProjectSession()
        let project = session.createProject(named: "First")
        let run = recordRun(session, in: project.id)!
        let router = AppRouter(destination: .setup(projectID: project.id))
        let factory = ProjectScreenFactory(services: AppServices(projectSession: session), router: router)
        let library = factory.makeLibraryViewModel()
        let before = factory.makeSavedDashboardViewModel(projectID: project.id, analysisID: run.id)

        library.requestDeletion(of: run, in: project)
        library.confirmDeletion()

        #expect(factory.makeSavedDashboardViewModel(projectID: project.id, analysisID: run.id) !== before)
    }

    @Test("Deleting a project that is not open leaves the page alone")
    func factoryLeavesTheOpenPage() {
        let session = ProjectSession()
        let first = session.createProject(named: "First")
        let second = session.createProject(named: "Second")
        let router = AppRouter(destination: .setup(projectID: first.id))
        let factory = ProjectScreenFactory(services: AppServices(projectSession: session), router: router)
        let library = factory.makeLibraryViewModel()

        library.requestDeletion(of: second)
        library.confirmDeletion()

        #expect(session.projects.map(\.id) == [first.id])
        #expect(router.destination == .setup(projectID: first.id))
    }

    @Test("Deleting a project clears the files it had in the import queue")
    func factoryClearsTheImportQueue() {
        let session = ProjectSession()
        let project = session.createProject(named: "First")
        let queue = ScriptedImportQueue(isSynchronous: true)
        queue.add(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")], kind: .legend, projectID: project.id)
        let services = AppServices(importQueue: queue, projectSession: session)
        let factory = ProjectScreenFactory(services: services, router: AppRouter())
        #expect(!queue.files(for: project.id).isEmpty)

        let library = factory.makeLibraryViewModel()
        library.requestDeletion(of: project)
        library.confirmDeletion()

        #expect(queue.files(for: project.id).isEmpty)
    }
}

import Foundation
import Observation

@Observable
@MainActor
final class ProjectLibraryViewModel {
    var searchText: String = ""
    private(set) var expandedProjectIDs: Set<UUID> = []
    var renamingAnalysisID: UUID?
    /// What the user asked to delete and has not yet confirmed. The window shows the question over the page.
    private(set) var pendingDeletion: PendingDeletion?

    enum PendingDeletion: Equatable {
        case project(ProjectSummary)
        case analysis(SavedAnalysis, in: ProjectSummary)

        var title: String {
            switch self {
            case .project: "Delete Project?"
            case .analysis: "Delete Analysis?"
            }
        }

        var message: String {
            switch self {
            case .project(let project): "Deleting “\(project.name)” will also remove its data."
            case .analysis(let analysis, _): "Deleting “\(analysis.name)” removes this saved analysis."
            }
        }
    }

    private let session: any ProjectSessionProtocol
    private let onOpenProject: (UUID) -> Void
    private let onOpenAnalysis: (UUID, UUID) -> Void
    private let onOpenLatestAnalysis: (UUID) -> Void
    private let destination: () -> AppDestination
    private let onDeleteProject: (UUID) -> Void
    private let onDeleteAnalysis: (UUID) -> Void

    /// `onOpenProject` opens the project's setup page. `destination` reads where the app is now, so the sidebar
    /// highlight follows the page and not the last click.
    init(
        session: any ProjectSessionProtocol,
        destination: @escaping () -> AppDestination = { .empty },
        onOpenProject: @escaping (UUID) -> Void,
        onOpenAnalysis: @escaping (UUID, UUID) -> Void = { _, _ in },
        onOpenLatestAnalysis: @escaping (UUID) -> Void = { _ in },
        onDeleteProject: @escaping (UUID) -> Void = { _ in },
        onDeleteAnalysis: @escaping (UUID) -> Void = { _ in }
    ) {
        self.session = session
        self.destination = destination
        self.onOpenProject = onOpenProject
        self.onOpenAnalysis = onOpenAnalysis
        self.onOpenLatestAnalysis = onOpenLatestAnalysis
        self.onDeleteProject = onDeleteProject
        self.onDeleteAnalysis = onDeleteAnalysis
        if let activeID = session.activeProjectID {
            expandedProjectIDs.insert(activeID)
        }
    }

    var projects: [ProjectSummary] {
        session.projects
    }

    var selectedProjectID: UUID? {
        session.activeProjectID
    }

    /// The project whose runs show under the list: the one opened last.
    var selectedProject: ProjectSummary? {
        session.projects.first { $0.id == session.activeProjectID }
    }

    /// The project is the one open, on any of its pages: its setup, the editor, an analysis or a saved run.
    func isProjectSelected(_ project: ProjectSummary) -> Bool {
        switch destination() {
        case .setup(let id), .review(let id), .editor(let id), .analysis(let id), .savedAnalysis(let id, _):
            id == project.id
        case .simulation(let id, _, _): id == project.id
        case .empty: false
        }
    }

    // MARK: Selection

    func isFolderSelected(_ project: ProjectSummary) -> Bool {
        switch destination() {
        case .setup(let id), .review(let id), .editor(let id): id == project.id
        case .empty, .analysis, .savedAnalysis, .simulation: false
        }
    }

    func isAnalysisSelected(_ analysis: SavedAnalysis, in project: ProjectSummary) -> Bool {
        switch destination() {
        case .savedAnalysis(let projectID, let analysisID):
            projectID == project.id && analysisID == analysis.id
        case .analysis(let projectID):
            projectID == project.id && !isRunning(project) && session.savedAnalyses(for: project.id).last?.id == analysis.id
        default: false
        }
    }

    /// A run is under way, so the folder shows a loading row until its analysis is saved.
    func isRunning(_ project: ProjectSummary) -> Bool {
        session.isSimulating(project.id)
    }

    func isRunningSelected(_ project: ProjectSummary) -> Bool {
        guard isRunning(project) else { return false }
        if case .analysis(let id) = destination() { return id == project.id }
        return false
    }

    func openRunning(_ project: ProjectSummary) {
        session.selectProject(id: project.id)
        onOpenLatestAnalysis(project.id)
    }

    var filteredProjects: [ProjectSummary] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return session.projects }
        return session.projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func createProject() {
        let name = nextFreeProjectName()
        let created = session.createProject(named: name)
        selectProject(created)
    }

    func selectProject(_ project: ProjectSummary) {
        session.selectProject(id: project.id)
        expandedProjectIDs.insert(project.id)
        onOpenProject(project.id)
    }

    func isExpanded(_ project: ProjectSummary) -> Bool {
        expandedProjectIDs.contains(project.id)
    }

    func toggleExpanded(_ project: ProjectSummary) {
        if !expandedProjectIDs.insert(project.id).inserted {
            expandedProjectIDs.remove(project.id)
        }
    }

    func savedAnalyses(in project: ProjectSummary) -> [SavedAnalysis] {
        session.savedAnalyses(for: project.id)
    }

    func selectAnalysis(_ analysis: SavedAnalysis, in project: ProjectSummary) {
        session.selectProject(id: project.id)
        onOpenAnalysis(project.id, analysis.id)
    }

    func renameAnalysis(_ analysis: SavedAnalysis, in project: ProjectSummary, to name: String) {
        session.renameSavedAnalysis(id: analysis.id, in: project.id, to: name)
        renamingAnalysisID = nil
    }

    // MARK: Deleting

    func requestDeletion(of project: ProjectSummary) {
        pendingDeletion = .project(project)
    }

    func requestDeletion(of analysis: SavedAnalysis, in project: ProjectSummary) {
        pendingDeletion = .analysis(analysis, in: project)
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }

    /// Carries out the deletion the user confirmed.
    func confirmDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        switch pending {
        case .project(let project):
            expandedProjectIDs.remove(project.id)
            onDeleteProject(project.id)
        case .analysis(let analysis, let project):
            deleteAnalysis(analysis, in: project)
        }
    }

    func deleteAnalysis(_ analysis: SavedAnalysis, in project: ProjectSummary) {
        session.deleteSavedAnalysis(id: analysis.id, in: project.id)
        onDeleteAnalysis(analysis.id)
        guard isShowing(analysis.id) else { return }
        onOpenProject(project.id)
    }

    /// The run's dashboard and its replay both show the run, so either one has to leave once it is deleted.
    private func isShowing(_ analysisID: UUID) -> Bool {
        switch destination() {
        case .savedAnalysis(_, let openID), .simulation(_, _, let openID?): openID == analysisID
        default: false
        }
    }

    private func nextFreeProjectName() -> String {
        let baseName = "Untitled"
        let existingNames = Set(session.projects.map(\.name))

        var candidate = baseName
        var number = 1
        while existingNames.contains(candidate) {
            number += 1
            candidate = "\(baseName) \(number)"
        }
        return candidate
    }
}

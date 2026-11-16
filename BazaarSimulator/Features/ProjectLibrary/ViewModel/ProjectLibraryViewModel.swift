import Foundation
import Observation

@Observable
@MainActor
final class ProjectLibraryViewModel {
    var searchText: String = ""

    private let session: any ProjectSessionProtocol
    private let onOpenProject: (UUID) -> Void
    private let onOpenResult: (SimulationResultTab) -> Void

    init(
        session: any ProjectSessionProtocol,
        onOpenProject: @escaping (UUID) -> Void,
        onOpenResult: @escaping (SimulationResultTab) -> Void = { _ in }
    ) {
        self.session = session
        self.onOpenProject = onOpenProject
        self.onOpenResult = onOpenResult
    }

    var projects: [ProjectSummary] {
        session.projects
    }

    var selectedProjectID: UUID? {
        session.activeProjectID
    }

    var resultTabs: [SimulationResultTab] {
        guard let selectedProjectID else { return [] }
        return session.resultTabs(for: selectedProjectID)
    }

    var selectedResultTabID: UUID? {
        guard let selectedProjectID else { return nil }
        return session.activeResultTabID(for: selectedProjectID)
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
        session.clearActiveResultTab(for: project.id)
        onOpenProject(project.id)
    }

    func selectResultTab(_ tab: SimulationResultTab) {
        session.selectProject(id: tab.projectID)
        session.selectResultTab(id: tab.id, for: tab.projectID)
        onOpenResult(tab)
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

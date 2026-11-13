import Foundation
import Observation

@Observable
@MainActor
final class ProjectLibraryViewModel {
    var searchText: String = ""

    private let session: any ProjectSessionProtocol
    private let onOpenProject: (UUID) -> Void

    init(session: any ProjectSessionProtocol, onOpenProject: @escaping (UUID) -> Void) {
        self.session = session
        self.onOpenProject = onOpenProject
    }

    var projects: [ProjectSummary] {
        session.projects
    }

    var selectedProjectID: UUID? {
        session.activeProjectID
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
        onOpenProject(project.id)
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

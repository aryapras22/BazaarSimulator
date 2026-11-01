import Foundation
import Observation

struct ProjectItem: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

@Observable
@MainActor
final class ProjectLibraryViewModel {
    var projects: [ProjectItem] = []
    var selectedProjectId: UUID?
    var searchText: String = ""

    private let session: any ProjectSessionProtocol
    private let router: AppRouter

    init(session: any ProjectSessionProtocol, router: AppRouter) {
        self.session = session
        self.router = router

        self.session.onProjectRenamed = { [weak self] id, newName in
            self?.renameProject(id: id, newName: newName)
        }
    }

    var filteredProjects: [ProjectItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return projects }
        return projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    func createProject() {
        let name = nextFreeProjectName()
        let project = ProjectItem(id: UUID(), name: name)
        projects.append(project)
        selectProject(project)
    }

    func selectProject(_ project: ProjectItem) {
        selectedProjectId = project.id
        session.selectProject(id: project.id, name: project.name)
        router.showSetup()
    }

    func renameProject(id: UUID, newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName
    }

    func nextFreeProjectName() -> String {
        var existingNumbers = Set<Int>()
        let prefix = "Bazaar "

        for project in projects where project.name.hasPrefix(prefix) {
            let suffix = project.name.dropFirst(prefix.count)
            if let number = Int(suffix) {
                existingNumbers.insert(number)
            }
        }

        var candidate = 1
        while existingNumbers.contains(candidate) {
            candidate += 1
        }
        return "\(prefix)\(candidate)"
    }
}

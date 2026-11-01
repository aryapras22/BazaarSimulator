import Foundation
import Observation

@MainActor
protocol ProjectSessionProtocol: AnyObject {
    var activeProjectId: UUID? { get set }
    var projectName: String { get set }
    var currentDraft: ProjectDraft? { get set }
    var onProjectRenamed: ((UUID, String) -> Void)? { get set }
    func selectProject(id: UUID, name: String)
    func setProjectName(_ name: String)
}

@Observable
@MainActor
final class ProjectSession: ProjectSessionProtocol {
    var activeProjectId: UUID?
    private var internalProjectName: String = ""

    var projectName: String {
        get { internalProjectName }
        set {
            internalProjectName = newValue
            if let activeProjectId {
                onProjectRenamed?(activeProjectId, newValue)
            }
        }
    }

    var currentDraft: ProjectDraft?

    @ObservationIgnored
    var onProjectRenamed: ((UUID, String) -> Void)?

    init(activeProjectId: UUID? = nil, projectName: String = "", currentDraft: ProjectDraft? = nil) {
        self.activeProjectId = activeProjectId
        self.internalProjectName = projectName
        self.currentDraft = currentDraft
    }

    func selectProject(id: UUID, name: String) {
        self.activeProjectId = id
        self.internalProjectName = name
    }

    func setProjectName(_ name: String) {
        self.projectName = name
    }
}

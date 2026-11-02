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
}

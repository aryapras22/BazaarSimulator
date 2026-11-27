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

import Foundation
import Observation

@MainActor
protocol ProjectSessionProtocol: AnyObject {
    var projects: [ProjectSummary] { get }
    var activeProjectID: UUID? { get }
    var activeProject: ProjectSummary? { get }

    @discardableResult
    func createProject(named name: String) -> ProjectSummary
    func selectProject(id: UUID)
    func renameProject(id: UUID, to name: String)

    func draft(for projectID: UUID) -> ProjectDraft?
    func setDraft(_ draft: ProjectDraft, for projectID: UUID)

    func layout(id: Layout.ID, in projectID: UUID) -> Layout?
    func updateLayout(_ layout: Layout, in projectID: UUID)
    func activeLayoutID(for projectID: UUID) -> Layout.ID?
    func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID)

    func parameters(for projectID: UUID) -> EventParameters
    func setParameters(_ parameters: EventParameters, for projectID: UUID)
    func simulationResult(for layoutID: Layout.ID, in projectID: UUID) -> SimulationResult?
    func setSimulationResult(_ result: SimulationResult, for layoutID: Layout.ID, in projectID: UUID)
    func runSimulations(for projectID: UUID)
    func isSimulating(_ projectID: UUID) -> Bool
}

@Observable
@MainActor
final class ProjectSession: ProjectSessionProtocol {
    private(set) var projects: [ProjectSummary] = []
    private(set) var activeProjectID: UUID?
    private var drafts: [UUID: ProjectDraft] = [:]
    private var activeLayoutIDs: [UUID: Layout.ID] = [:]
    private var parametersByProject: [UUID: EventParameters] = [:]
    private var simulationResultsByProject: [UUID: [Layout.ID: SimulationResult]] = [:]
    private var simulationTasks: [UUID: Task<Void, Never>] = [:]
    private var simulatingProjects: Set<UUID> = []

    var activeProject: ProjectSummary? {
        projects.first { $0.id == activeProjectID }
    }

    @discardableResult
    func createProject(named name: String) -> ProjectSummary {
        let summary = ProjectSummary(name: name)
        projects.append(summary)
        return summary
    }

    func selectProject(id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        activeProjectID = id
    }

    func renameProject(id: UUID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
    }

    func draft(for projectID: UUID) -> ProjectDraft? {
        drafts[projectID]
    }

    func setDraft(_ draft: ProjectDraft, for projectID: UUID) {
        drafts[projectID] = draft
        if let activeID = activeLayoutIDs[projectID],
           draft.layouts.contains(where: { $0.id == activeID }) {
            return
        }
        activeLayoutIDs[projectID] = draft.layouts.first?.id
    }

    func layout(id: Layout.ID, in projectID: UUID) -> Layout? {
        drafts[projectID]?.layouts.first { $0.id == id }
    }

    func updateLayout(_ layout: Layout, in projectID: UUID) {
        guard var currentDraft = drafts[projectID],
              let index = currentDraft.layouts.firstIndex(where: { $0.id == layout.id }) else {
            return
        }
        currentDraft.layouts[index] = layout
        drafts[projectID] = currentDraft
    }

    func activeLayoutID(for projectID: UUID) -> Layout.ID? {
        if let activeID = activeLayoutIDs[projectID],
           drafts[projectID]?.layouts.contains(where: { $0.id == activeID }) == true {
            return activeID
        }
        return drafts[projectID]?.layouts.first?.id
    }

    func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID) {
        guard drafts[projectID]?.layouts.contains(where: { $0.id == id }) == true else { return }
        activeLayoutIDs[projectID] = id
    }

    // MARK: - Parameters & Simulation Results

    func parameters(for projectID: UUID) -> EventParameters {
        parametersByProject[projectID] ?? EventParameters()
    }

    func setParameters(_ parameters: EventParameters, for projectID: UUID) {
        parametersByProject[projectID] = parameters
    }

    func simulationResult(for layoutID: Layout.ID, in projectID: UUID) -> SimulationResult? {
        simulationResultsByProject[projectID]?[layoutID]
    }

    func setSimulationResult(_ result: SimulationResult, for layoutID: Layout.ID, in projectID: UUID) {
        var projectMap = simulationResultsByProject[projectID] ?? [:]
        projectMap[layoutID] = result
        simulationResultsByProject[projectID] = projectMap
    }

    func isSimulating(_ projectID: UUID) -> Bool {
        simulatingProjects.contains(projectID)
    }

    /// Replaces the project's results in the background. A newer run cancels one still going.
    func runSimulations(for projectID: UUID) {
        guard let layouts = drafts[projectID]?.layouts, !layouts.isEmpty else { return }
        let settings = parameters(for: projectID).toSimulationSettings()
        let legend = drafts[projectID]?.legend ?? Legend()

        simulationTasks[projectID]?.cancel()
        simulationResultsByProject[projectID] = [:]
        simulatingProjects.insert(projectID)
        simulationTasks[projectID] = Task { [weak self] in
            let engines = layouts.map {
                (id: $0.id, engine: SimulationEngine(layout: $0, settings: settings, legend: legend))
            }
            await withTaskGroup(of: (Layout.ID, SimulationResult)?.self) { group in
                for item in engines {
                    group.addTask {
                        guard !Task.isCancelled else { return nil }
                        let result = await item.engine.runWithRecordedFootage(
                            durationMinutes: settings.durationMinutes,
                            frameIntervalSeconds: CrowdParameters.defaultFrameIntervalSeconds
                        )
                        return Task.isCancelled ? nil : (item.id, result)
                    }
                }
                for await pair in group {
                    if Task.isCancelled { return }
                    if let (layoutID, result) = pair {
                        self?.setSimulationResult(result, for: layoutID, in: projectID)
                    }
                }
            }
            if !Task.isCancelled {
                self?.simulatingProjects.remove(projectID)
            }
        }
    }
}

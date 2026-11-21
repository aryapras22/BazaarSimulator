import Foundation
import Observation

@MainActor
protocol ProjectSessionProtocol: AnyObject {
    var projects: [ProjectSummary] { get }
    var activeProjectID: UUID? { get }
    var activeProject: ProjectSummary? { get }

    @discardableResult
    func createProject(named name: String) -> ProjectSummary
    func project(named name: String) -> ProjectSummary?
    func selectProject(id: UUID)
    func renameProject(id: UUID, to name: String)
    /// Removes the project with its layouts, parameters, results, and saved analyses.
    func deleteProject(id: UUID)

    func eventParameters(for projectID: UUID) -> EventParameters?
    func setEventParameters(_ parameters: EventParameters, for projectID: UUID)

    func draft(for projectID: UUID) -> ProjectDraft?
    func setDraft(_ draft: ProjectDraft, for projectID: UUID)

    func layout(id: Layout.ID, in projectID: UUID) -> Layout?
    func updateLayout(_ layout: Layout, in projectID: UUID)
    func activeLayoutID(for projectID: UUID) -> Layout.ID?
    func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID)
    /// The layouts the Analysis page shows, in page order: the project's first two until others are picked.
    func comparedLayouts(for projectID: UUID) -> [Layout]
    /// Puts a layout at one place on the Analysis page. A layout already at the other place swaps with it.
    func setComparedLayout(_ id: Layout.ID, at index: Int, for projectID: UUID)

    func parameters(for projectID: UUID) -> ModalParameters
    func setParameters(_ parameters: ModalParameters, for projectID: UUID)
    func simulationResult(for layoutID: Layout.ID, in projectID: UUID) -> RecordedSimulationResult?
    func setSimulationResult(_ result: RecordedSimulationResult, for layoutID: Layout.ID, in projectID: UUID)
    func runSimulations(for projectID: UUID)
    func savedAnalyses(for projectID: UUID) -> [SavedAnalysis]
    /// Keeps a finished analysis as the project's next saved run. Nothing is added when the latest saved run was
    /// made from the same layouts and parameters.
    @discardableResult
    func recordAnalysis(
        layouts: [Layout], analyses: [LayoutAnalysis], parameters: EventParameters, peakMinute: Int, in projectID: UUID
    ) -> SavedAnalysis?
    /// Marks an analysis as under way, so the sidebar shows a loading row under the project.
    func setAnalysisRunning(_ isRunning: Bool, for projectID: UUID)
    func savedAnalysis(id: SavedAnalysis.ID, in projectID: UUID) -> SavedAnalysis?
    func renameSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID, to name: String)
    func deleteSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID)
    func isSimulating(_ projectID: UUID) -> Bool
}

@Observable
@MainActor
final class ProjectSession: ProjectSessionProtocol {
    private(set) var projects: [ProjectSummary] = []
    private(set) var activeProjectID: UUID?
    private var drafts: [UUID: ProjectDraft] = [:]
    private var eventParametersByProject: [UUID: EventParameters] = [:]
    private var activeLayoutIDs: [UUID: Layout.ID] = [:]
    private var comparedLayoutIDs: [UUID: [Layout.ID]] = [:]
    private var parametersByProject: [UUID: ModalParameters] = [:]
    private var simulationResultsByProject: [UUID: [Layout.ID: RecordedSimulationResult]] = [:]
    private var simulationTasks: [UUID: Task<Void, Never>] = [:]
    private var simulatingProjects: Set<UUID> = []
    private var analysingProjects: Set<UUID> = []
    private var savedAnalysesByProject: [UUID: [SavedAnalysis]] = [:]
    private let store: (any SavedAnalysisStoring)?

    /// With a store, projects and saved analyses are read from it now and written to it as they change.
    init(store: (any SavedAnalysisStoring)? = nil) {
        self.store = store
        guard let store else { return }
        projects = store.loadProjects()
        for project in projects {
            savedAnalysesByProject[project.id] = store.loadAnalyses(for: project.id)
        }
    }

    var activeProject: ProjectSummary? {
        projects.first { $0.id == activeProjectID }
    }

    @discardableResult
    func createProject(named name: String) -> ProjectSummary {
        let summary = ProjectSummary(name: name)
        projects.append(summary)
        store?.saveProjects(projects)
        return summary
    }

    func project(named name: String) -> ProjectSummary? {
        projects.first { $0.name == name }
    }

    func selectProject(id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        activeProjectID = id
    }

    func renameProject(id: UUID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
        store?.saveProjects(projects)
    }

    func eventParameters(for projectID: UUID) -> EventParameters? {
        eventParametersByProject[projectID]
    }

    func setEventParameters(_ parameters: EventParameters, for projectID: UUID) {
        eventParametersByProject[projectID] = parameters
        parametersByProject[projectID] = ModalParameters(
            totalVisitors: parameters.totalVisitors,
            startMinutes: parameters.eventHours.startMinute,
            endMinutes: parameters.eventHours.endMinute,
            bazaarType: parameters.bazaarTypeID,
            socializerPercent: Double(parameters.mix.share(for: "socializer")?.percent ?? 20),
            familyMemberPercent: Double(parameters.mix.share(for: "family")?.percent ?? 50),
            explorerPercent: Double(parameters.mix.share(for: "explorer")?.percent ?? 15),
            purposeBuyerPercent: Double(parameters.mix.share(for: "buyer")?.percent ?? 15)
        )
    }

    func deleteProject(id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        simulationTasks[id]?.cancel()
        simulationTasks[id] = nil
        projects.removeAll { $0.id == id }
        if activeProjectID == id { activeProjectID = nil }
        drafts[id] = nil
        activeLayoutIDs[id] = nil
        comparedLayoutIDs[id] = nil
        eventParametersByProject[id] = nil
        parametersByProject[id] = nil
        simulationResultsByProject[id] = nil
        simulatingProjects.remove(id)
        analysingProjects.remove(id)
        savedAnalysesByProject[id] = nil
        store?.saveProjects(projects)
        store?.deleteAnalyses(of: id)
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

    func parameters(for projectID: UUID) -> ModalParameters {
        parametersByProject[projectID] ?? ModalParameters()
    }

    func setParameters(_ parameters: ModalParameters, for projectID: UUID) {
        parametersByProject[projectID] = parameters
    }

    func simulationResult(for layoutID: Layout.ID, in projectID: UUID) -> RecordedSimulationResult? {
        simulationResultsByProject[projectID]?[layoutID]
    }

    func setSimulationResult(_ result: RecordedSimulationResult, for layoutID: Layout.ID, in projectID: UUID) {
        var projectMap = simulationResultsByProject[projectID] ?? [:]
        projectMap[layoutID] = result
        simulationResultsByProject[projectID] = projectMap
    }

    static let comparedLayoutCount = 2

    func comparedLayouts(for projectID: UUID) -> [Layout] {
        let layouts = drafts[projectID]?.layouts ?? []
        // A picked layout that was removed from the project gives its place back to the first one not shown.
        var shown = (comparedLayoutIDs[projectID] ?? []).compactMap { id in layouts.first { $0.id == id } }
        for layout in layouts where shown.count < Self.comparedLayoutCount && !shown.contains(where: { $0.id == layout.id }) {
            shown.append(layout)
        }
        return Array(shown.prefix(Self.comparedLayoutCount))
    }

    func setComparedLayout(_ id: Layout.ID, at index: Int, for projectID: UUID) {
        var shown = comparedLayouts(for: projectID).map(\.id)
        guard shown.indices.contains(index), layout(id: id, in: projectID) != nil else { return }
        if let other = shown.firstIndex(of: id) {
            shown.swapAt(index, other)
        } else {
            shown[index] = id
        }
        comparedLayoutIDs[projectID] = shown
    }

    func isSimulating(_ projectID: UUID) -> Bool {
        simulatingProjects.contains(projectID) || analysingProjects.contains(projectID)
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
            await withTaskGroup(of: (Layout.ID, RecordedSimulationResult)?.self) { group in
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

    // MARK: - Saved analyses

    func savedAnalyses(for projectID: UUID) -> [SavedAnalysis] {
        savedAnalysesByProject[projectID] ?? []
    }

    func savedAnalysis(id: SavedAnalysis.ID, in projectID: UUID) -> SavedAnalysis? {
        savedAnalyses(for: projectID).first { $0.id == id }
    }

    func renameSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID, to name: String) {
        guard let index = savedAnalysesByProject[projectID]?.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        savedAnalysesByProject[projectID]?[index].name = trimmed
        if let renamed = savedAnalysesByProject[projectID]?[index] { store?.save(renamed, in: projectID) }
    }

    func deleteSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID) {
        savedAnalysesByProject[projectID]?.removeAll { $0.id == id }
        store?.delete(analysisID: id, in: projectID)
    }

    @discardableResult
    func recordAnalysis(
        layouts: [Layout], analyses: [LayoutAnalysis], parameters: EventParameters, peakMinute: Int, in projectID: UUID
    ) -> SavedAnalysis? {
        let existing = savedAnalyses(for: projectID)
        if existing.last?.matches(parameters: parameters, layouts: layouts) == true { return nil }
        let saved = SavedAnalysis(
            number: (existing.map(\.number).max() ?? 0) + 1,
            parameters: parameters,
            layouts: layouts,
            analyses: analyses,
            peakMinute: peakMinute
        )
        savedAnalysesByProject[projectID, default: []].append(saved)
        store?.save(saved, in: projectID)
        return saved
    }

    func setAnalysisRunning(_ isRunning: Bool, for projectID: UUID) {
        if isRunning {
            analysingProjects.insert(projectID)
        } else {
            analysingProjects.remove(projectID)
        }
    }
}

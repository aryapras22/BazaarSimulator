import Foundation
import Observation

/// A saved simulation result entry stacked in the sidebar for a specific project.
struct SimulationResultTab: Identifiable, Equatable, Sendable {
    let id: UUID
    let projectID: UUID
    let title: String
    let subtitle: String
    let parameters: EventParameters
}

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

    func eventParameters(for projectID: UUID) -> EventParameters?
    func setEventParameters(_ parameters: EventParameters, for projectID: UUID)

    func resultTabs(for projectID: UUID) -> [SimulationResultTab]
    func activeResultTabID(for projectID: UUID) -> UUID?
    @discardableResult
    func addResultTab(for projectID: UUID, parameters: EventParameters) -> SimulationResultTab
    func selectResultTab(id: UUID, for projectID: UUID)
    func clearActiveResultTab(for projectID: UUID)

    func draft(for projectID: UUID) -> ProjectDraft?
    func setDraft(_ draft: ProjectDraft, for projectID: UUID)

    func layout(id: Layout.ID, in projectID: UUID) -> Layout?
    func updateLayout(_ layout: Layout, in projectID: UUID)
    func activeLayoutID(for projectID: UUID) -> Layout.ID?
    func setActiveLayoutID(_ id: Layout.ID, for projectID: UUID)

    func parameters(for projectID: UUID) -> ModalParameters
    func setParameters(_ parameters: ModalParameters, for projectID: UUID)
    func simulationResult(for layoutID: Layout.ID, in projectID: UUID) -> RecordedSimulationResult?
    func setSimulationResult(_ result: RecordedSimulationResult, for layoutID: Layout.ID, in projectID: UUID)
    func runSimulations(for projectID: UUID)
    func savedAnalyses(for projectID: UUID) -> [SavedAnalysis]
    func savedAnalysis(id: SavedAnalysis.ID, in projectID: UUID) -> SavedAnalysis?
    func renameSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID, to name: String)
    func deleteSavedAnalysis(id: SavedAnalysis.ID, in projectID: UUID)
    func isSimulating(_ projectID: UUID) -> Bool
}

extension ProjectSessionProtocol {
    func resultTabs(for projectID: UUID) -> [SimulationResultTab] { [] }
    func activeResultTabID(for projectID: UUID) -> UUID? { nil }
    @discardableResult
    func addResultTab(for projectID: UUID, parameters: EventParameters) -> SimulationResultTab {
        SimulationResultTab(id: UUID(), projectID: projectID, title: "Result 1", subtitle: "", parameters: parameters)
    }
    func selectResultTab(id: UUID, for projectID: UUID) {}
    func clearActiveResultTab(for projectID: UUID) {}
}

@Observable
@MainActor
final class ProjectSession: ProjectSessionProtocol {
    private(set) var projects: [ProjectSummary] = []
    private(set) var activeProjectID: UUID?
    private var drafts: [UUID: ProjectDraft] = [:]
    private var eventParametersByProject: [UUID: EventParameters] = [:]
    private var resultTabsByProject: [UUID: [SimulationResultTab]] = [:]
    private var activeResultTabIDByProject: [UUID: UUID] = [:]
    private var activeLayoutIDs: [UUID: Layout.ID] = [:]
    private var parametersByProject: [UUID: ModalParameters] = [:]
    private var simulationResultsByProject: [UUID: [Layout.ID: RecordedSimulationResult]] = [:]
    private var simulationTasks: [UUID: Task<Void, Never>] = [:]
    private var simulatingProjects: Set<UUID> = []
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
            socializerPercent: Double(parameters.mix.share(for: "socializer")?.percent ?? 21),
            familyMemberPercent: Double(parameters.mix.share(for: "family")?.percent ?? 46),
            strollerPercent: Double(parameters.mix.share(for: "stroller")?.percent ?? 33),
            purposeBuyerPercent: Double(parameters.mix.share(for: "buyer")?.percent ?? 0)
        )
    }

    func resultTabs(for projectID: UUID) -> [SimulationResultTab] {
        resultTabsByProject[projectID] ?? []
    }

    func activeResultTabID(for projectID: UUID) -> UUID? {
        activeResultTabIDByProject[projectID]
    }

    @discardableResult
    func addResultTab(for projectID: UUID, parameters: EventParameters) -> SimulationResultTab {
        var existing = resultTabsByProject[projectID] ?? []
        let nextNumber = existing.count + 1
        let hoursText = "\(TimeRange.format(parameters.eventHours.startMinute))–\(TimeRange.format(parameters.eventHours.endMinute))"
        let tab = SimulationResultTab(
            id: UUID(),
            projectID: projectID,
            title: "Result \(nextNumber)",
            subtitle: "\(parameters.totalVisitors) visitors · \(hoursText)",
            parameters: parameters
        )
        existing.append(tab)
        resultTabsByProject[projectID] = existing
        activeResultTabIDByProject[projectID] = tab.id
        return tab
    }

    func selectResultTab(id: UUID, for projectID: UUID) {
        guard let tab = resultTabsByProject[projectID]?.first(where: { $0.id == id }) else { return }
        activeResultTabIDByProject[projectID] = tab.id
        setEventParameters(tab.parameters, for: projectID)
    }

    func clearActiveResultTab(for projectID: UUID) {
        activeResultTabIDByProject[projectID] = nil
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

    func isSimulating(_ projectID: UUID) -> Bool {
        simulatingProjects.contains(projectID)
    }

    /// Replaces the project's results in the background. A newer run cancels one still going.
    func runSimulations(for projectID: UUID) {
        guard let layouts = drafts[projectID]?.layouts, !layouts.isEmpty else { return }
        let eventParameters = parameters(for: projectID)
        let settings = eventParameters.toSimulationSettings()
        let legend = drafts[projectID]?.legend ?? Legend()

        simulationTasks[projectID]?.cancel()
        simulationResultsByProject[projectID] = [:]
        simulatingProjects.insert(projectID)
        simulationTasks[projectID] = Task { [weak self] in
            var measurements: [LayoutAnalysis] = []
            var peakMinute = eventParameters.startMinutes
            for layout in layouts {
                let engine = SimulationEngine(layout: layout, settings: settings, legend: legend)
                let result = await engine.runWithRecordedFootage(
                    durationMinutes: settings.durationMinutes,
                    frameIntervalSeconds: 5.0
                )
                if Task.isCancelled { return }
                self?.setSimulationResult(result, for: layout.id, in: projectID)
                if measurements.isEmpty { peakMinute = LayoutMeasurementBuilder.busiestMinute(in: result) }
                measurements.append(
                    LayoutMeasurementBuilder.build(result: result, layout: layout, parameters: eventParameters)
                )
            }
            self?.saveAnalysis(
                SavedRun(layouts: layouts, measurements: measurements, parameters: eventParameters, peakMinute: peakMinute),
                in: projectID
            )
            self?.simulatingProjects.remove(projectID)
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

    private struct SavedRun {
        let layouts: [Layout]
        let measurements: [LayoutAnalysis]
        let parameters: EventParameters
        let peakMinute: Int
    }

    private func saveAnalysis(_ run: SavedRun, in projectID: UUID) {
        let number = (savedAnalyses(for: projectID).map(\.number).max() ?? 0) + 1
        let saved = SavedAnalysis(
            number: number,
            parameters: run.parameters,
            layouts: run.layouts,
            measurements: run.measurements,
            peakMinute: run.peakMinute
        )
        savedAnalysesByProject[projectID, default: []].append(saved)
        store?.save(saved, in: projectID)
    }
}

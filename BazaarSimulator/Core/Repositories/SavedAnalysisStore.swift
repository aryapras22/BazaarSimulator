import Foundation
import os

/// Persisted per-project session selections stored additively alongside drafts and analyses.
struct ProjectSessionState: Codable, Equatable, Sendable {
    var eventParameters: EventParameters?
    var comparedLayoutIDs: [Layout.ID]?

    init(eventParameters: EventParameters? = nil, comparedLayoutIDs: [Layout.ID]? = nil) {
        self.eventParameters = eventParameters
        self.comparedLayoutIDs = comparedLayoutIDs
    }
}

/// Where projects, drafts, session state, and their saved analyses are kept between launches.
protocol SavedAnalysisStoring: Sendable {
    func loadProjects() -> [ProjectSummary]
    func saveProjects(_ projects: [ProjectSummary])
    func loadDraft(for projectID: UUID) -> ProjectDraft?
    func saveDraft(_ draft: ProjectDraft, for projectID: UUID)
    func deleteDraft(for projectID: UUID)
    func loadState(for projectID: UUID) -> ProjectSessionState?
    func saveState(_ state: ProjectSessionState, for projectID: UUID)
    func deleteState(for projectID: UUID)
    func loadAnalyses(for projectID: UUID) -> [SavedAnalysis]
    func save(_ analysis: SavedAnalysis, in projectID: UUID)
    func delete(analysisID: UUID, in projectID: UUID)
    /// Removes every saved analysis of the project. The project list is saved separately.
    func deleteAnalyses(of projectID: UUID)
}

/// One JSON file per project draft, per project state, and per saved analysis:
/// `<root>/Projects.json`, `<root>/Drafts/<project id>.json`, `<root>/State/<project id>.json`, and
/// `<root>/Analyses/<project id>/<analysis id>.json`.
/// Files are small, so writes finish before the call returns. Nothing is lost if the app quits right after a save.
final class FileSavedAnalysisStore: SavedAnalysisStoring, @unchecked Sendable {
    private let root: URL
    var rootForTesting: URL { root }
    private let queue = DispatchQueue(label: "BazaarSimulator.SavedAnalysisStore")
    private let logger = Logger(subsystem: "BazaarSimulator", category: "SavedAnalysisStore")

    init(root: URL = FileSavedAnalysisStore.defaultRoot) {
        self.root = root
    }

    static var defaultRoot: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BazaarSimulator", isDirectory: true)
    }

    private var projectsFile: URL { root.appendingPathComponent("Projects.json") }

    private func draftFile(for projectID: UUID) -> URL {
        root.appendingPathComponent("Drafts", isDirectory: true)
            .appendingPathComponent("\(projectID.uuidString).json")
    }

    private func stateFile(for projectID: UUID) -> URL {
        root.appendingPathComponent("State", isDirectory: true)
            .appendingPathComponent("\(projectID.uuidString).json")
    }

    private func folder(for projectID: UUID) -> URL {
        root.appendingPathComponent("Analyses", isDirectory: true)
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
    }

    func loadProjects() -> [ProjectSummary] {
        queue.sync { read([ProjectSummary].self, from: projectsFile) ?? [] }
    }

    func saveProjects(_ projects: [ProjectSummary]) {
        let file = projectsFile
        queue.sync { write(projects, to: file) }
    }

    func loadDraft(for projectID: UUID) -> ProjectDraft? {
        queue.sync { read(ProjectDraft.self, from: draftFile(for: projectID)) }
    }

    func saveDraft(_ draft: ProjectDraft, for projectID: UUID) {
        let file = draftFile(for: projectID)
        queue.sync { write(draft, to: file) }
    }

    func deleteDraft(for projectID: UUID) {
        let file = draftFile(for: projectID)
        queue.sync { try? FileManager.default.removeItem(at: file) }
    }

    func loadState(for projectID: UUID) -> ProjectSessionState? {
        queue.sync { read(ProjectSessionState.self, from: stateFile(for: projectID)) }
    }

    func saveState(_ state: ProjectSessionState, for projectID: UUID) {
        let file = stateFile(for: projectID)
        queue.sync { write(state, to: file) }
    }

    func deleteState(for projectID: UUID) {
        let file = stateFile(for: projectID)
        queue.sync { try? FileManager.default.removeItem(at: file) }
    }

    func loadAnalyses(for projectID: UUID) -> [SavedAnalysis] {
        queue.sync {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: folder(for: projectID), includingPropertiesForKeys: nil
            )) ?? []
            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { read(SavedAnalysis.self, from: $0) }
                .sorted { $0.createdAt < $1.createdAt }
        }
    }

    func save(_ analysis: SavedAnalysis, in projectID: UUID) {
        let file = folder(for: projectID).appendingPathComponent("\(analysis.id.uuidString).json")
        queue.sync { write(analysis, to: file) }
    }

    func delete(analysisID: UUID, in projectID: UUID) {
        let file = folder(for: projectID).appendingPathComponent("\(analysisID.uuidString).json")
        queue.sync { try? FileManager.default.removeItem(at: file) }
    }

    func deleteAnalyses(of projectID: UUID) {
        let folder = folder(for: projectID)
        queue.sync { try? FileManager.default.removeItem(at: folder) }
    }

    // MARK: - Files

    private func read<Value: Decodable>(_ type: Value.Type, from file: URL) -> Value? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            logger.error("Could not read \(file.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private func write<Value: Encodable>(_ value: Value, to file: URL) {
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(value).write(to: file, options: .atomic)
        } catch {
            logger.error("Could not write \(file.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

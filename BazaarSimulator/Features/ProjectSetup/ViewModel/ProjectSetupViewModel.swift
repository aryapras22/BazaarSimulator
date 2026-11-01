import Foundation
import Observation

@Observable
@MainActor
final class ProjectSetupViewModel {
    let projectID: UUID
    private let session: any ProjectSessionProtocol
    private let importQueue: any ImportQueueing
    private let onContinue: (UUID) -> Void

    var projectName: String {
        get { session.projects.first { $0.id == projectID }?.name ?? "" }
        set { session.renameProject(id: projectID, to: newValue) }
    }

    private var removedLegendEntryIDs: Set<UUID> = []
    var bannerMessage: String?

    var legendEntries: [LegendEntry] {
        guard let queueLegend = importQueue.legend(for: projectID) else { return [] }
        return queueLegend.entries.filter { !removedLegendEntryIDs.contains($0.id) }
    }

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        importQueue: any ImportQueueing,
        onContinue: @escaping (UUID) -> Void
    ) {
        self.projectID = projectID
        self.session = session
        self.importQueue = importQueue
        self.onContinue = onContinue
    }

    var legendFiles: [ImportFile] {
        importQueue.files(for: projectID).filter { $0.kind == .legend }
    }

    var pendingLegendRows: [PlanRowDisplay] {
        legendFiles.filter { file in
            if case .done = file.state { return false }
            return true
        }.map { file in
            ImportRowFormatter.formatLegendRow(file: file)
        }
    }

    var floorPlanFiles: [ImportFile] {
        importQueue.files(for: projectID).filter { $0.kind == .floorPlan }
    }

    var planRows: [PlanRowDisplay] {
        floorPlanFiles.enumerated().map { index, file in
            ImportRowFormatter.formatRow(file: file, layoutIndex: index + 1)
        }
    }

    var hasLegend: Bool {
        importQueue.legend(for: projectID) != nil
    }

    var isFloorPlanZoneEnabled: Bool {
        hasLegend && floorPlanFiles.count < 6
    }

    var hasPendingFiles: Bool {
        importQueue.files(for: projectID).contains { file in
            if case .reading = file.state { return true }
            if case .waiting = file.state { return true }
            return false
        }
    }

    var isCancelEnabled: Bool {
        hasPendingFiles
    }

    var isContinueEnabled: Bool {
        guard !projectName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !legendEntries.isEmpty else { return false }
        guard !floorPlanFiles.isEmpty else { return false }

        for file in floorPlanFiles {
            switch file.state {
            case .done:
                continue
            case .waiting, .reading, .failed, .cancelled:
                return false
            }
        }
        return true
    }

    var statusText: String {
        if let bannerMessage {
            return bannerMessage
        }

        if legendFiles.contains(where: {
            if case .reading = $0.state { return true }
            if case .waiting = $0.state { return true }
            return false
        }) {
            return "Reading the legend..."
        }

        if let firstReadingIndex = floorPlanFiles.firstIndex(where: {
            if case .reading = $0.state { return true }
            if case .waiting = $0.state { return true }
            return false
        }) {
            return "Waiting for Layout \(firstReadingIndex + 1) to finish reading..."
        }

        let allDone = !floorPlanFiles.isEmpty && floorPlanFiles.allSatisfy {
            if case .done = $0.state { return true }
            return false
        }

        if allDone && hasLegend {
            if legendEntries.isEmpty {
                return "Keep at least one legend category to continue"
            }
            if projectName.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Name the project to continue"
            }
            return "Ready to continue"
        }

        return "Add a legend and floor plans to continue"
    }

    func addLegendFiles(urls: [URL]) {
        guard validatePDFs(urls: urls) else { return }
        bannerMessage = nil
        importQueue.add(urls: urls, kind: .legend, projectID: projectID)
    }

    func addFloorPlanFiles(urls: [URL]) {
        guard hasLegend else {
            bannerMessage = "Add a legend before uploading floor plans"
            return
        }

        guard validatePDFs(urls: urls) else { return }

        let capacity = max(0, 6 - floorPlanFiles.count)
        guard capacity > 0 else {
            bannerMessage = "At most 6 floor plans allowed"
            return
        }

        let acceptedURLs = Array(urls.prefix(capacity))
        if acceptedURLs.count < urls.count {
            bannerMessage = "At most 6 floor plans allowed"
        } else {
            bannerMessage = nil
        }

        importQueue.add(urls: acceptedURLs, kind: .floorPlan, projectID: projectID)
    }

    func removeLegendEntry(id: UUID) {
        removedLegendEntryIDs.insert(id)
    }

    func deleteFloorPlan(id: UUID) {
        bannerMessage = nil
        importQueue.remove(fileID: id)
    }

    func retryFloorPlan(id: UUID) {
        bannerMessage = nil
        importQueue.retry(fileID: id)
    }

    func deleteLegendFile(id: UUID) {
        bannerMessage = nil
        importQueue.remove(fileID: id)
    }

    func retryLegendFile(id: UUID) {
        bannerMessage = nil
        importQueue.retry(fileID: id)
    }

    func cancel() {
        bannerMessage = nil
        importQueue.cancel(projectID: projectID)
    }

    func continueToReview() {
        guard isContinueEnabled else { return }

        let layouts = floorPlanFiles.compactMap { importQueue.extractedLayout(for: $0.id) }
        guard layouts.count == floorPlanFiles.count else {
            bannerMessage = "Some floor plans could not be read"
            return
        }

        let draft = ProjectDraft(
            name: projectName,
            legend: Legend(entries: legendEntries),
            layouts: layouts
        )

        session.setDraft(draft, for: projectID)
        onContinue(projectID)
    }

    private func validatePDFs(urls: [URL]) -> Bool {
        for url in urls where url.pathExtension.lowercased() != "pdf" {
            bannerMessage = "Only PDF files are accepted"
            return false
        }
        return true
    }
}

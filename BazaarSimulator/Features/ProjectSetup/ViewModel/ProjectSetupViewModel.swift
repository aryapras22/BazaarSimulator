import Foundation
import Observation

@Observable
@MainActor
final class ProjectSetupViewModel {
    let projectID: UUID
    let session: any ProjectSessionProtocol
    let importQueue: any ImportQueueing
    let onContinue: (UUID) -> Void

    var projectName: String {
        get { session.projects.first { $0.id == projectID }?.name ?? "" }
        set { session.renameProject(id: projectID, to: newValue) }
    }

    var legendEntries: [LegendEntry] = []
    var bannerMessage: String?

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

        if let existingLegend = importQueue.legend(for: projectID) {
            self.legendEntries = existingLegend.entries
        }
    }

    var floorPlanFiles: [ImportFile] {
        importQueue.files(for: projectID).filter { $0.kind == .floorPlan }
    }

    var hasLegend: Bool {
        !legendEntries.isEmpty || importQueue.legend(for: projectID) != nil
    }

    var isFloorPlanZoneEnabled: Bool {
        hasLegend && floorPlanFiles.count < 6
    }

    var isReadingAnyFile: Bool {
        importQueue.files(for: projectID).contains { file in
            if case .reading = file.state { return true }
            if case .waiting = file.state { return true }
            return false
        }
    }

    var isCancelEnabled: Bool {
        isReadingAnyFile
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

        if allDone && !legendEntries.isEmpty {
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
        if let queueLegend = importQueue.legend(for: projectID) {
            legendEntries = queueLegend.entries
        }
    }

    func addFloorPlanFiles(urls: [URL]) {
        guard hasLegend else {
            bannerMessage = "Add a legend before uploading floor plans"
            return
        }

        guard validatePDFs(urls: urls) else { return }

        if floorPlanFiles.count + urls.count > 6 {
            bannerMessage = "At most 6 floor plans allowed"
            return
        }

        bannerMessage = nil
        importQueue.add(urls: urls, kind: .floorPlan, projectID: projectID)
    }

    func removeLegendEntry(id: UUID) {
        legendEntries.removeAll { $0.id == id }
    }

    func deleteFloorPlan(id: UUID) {
        importQueue.remove(fileID: id)
    }

    func retryFloorPlan(id: UUID) {
        importQueue.retry(fileID: id)
    }

    func cancel() {
        importQueue.cancel(projectID: projectID)
    }

    func continueToReview() {
        guard isContinueEnabled else { return }

        var layouts: [ExtractedLayout] = []
        for file in floorPlanFiles {
            if let layout = importQueue.extractedLayout(for: file.id) {
                layouts.append(layout)
            } else {
                layouts.append(ExtractedLayout(
                    id: file.id,
                    name: file.url.deletingPathExtension().lastPathComponent,
                    sizeInMetres: LayoutDimensions(width: 70.1, height: 84.2),
                    booths: 66,
                    doors: 3
                ))
            }
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

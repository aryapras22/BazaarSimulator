import Foundation
import Observation

/// Reads one file at a time, legends first, so only one reading pass is in memory at once.
@Observable
@MainActor
final class ImportQueue: ImportQueueing {
    private(set) var files: [ImportFile] = []
    private var legendsByFile: [UUID: Legend] = [:]
    private var extractedLayouts: [UUID: ExtractedLayout] = [:]

    private let pdf: any PDFImporting
    private let reader: any FloorPlanReading
    private var worker: Task<Void, Never>?
    private var currentFileID: UUID?

    init(pdf: any PDFImporting, reader: any FloorPlanReading) {
        self.pdf = pdf
        self.reader = reader
    }

    func files(for projectID: UUID) -> [ImportFile] {
        files.filter { $0.projectID == projectID }
    }

    func legend(for projectID: UUID) -> Legend? {
        let entries = files(for: projectID)
            .filter { $0.kind == .legend }
            .compactMap { legendsByFile[$0.id] }
            .flatMap(\.entries)
        return entries.isEmpty ? nil : Legend(entries: entries)
    }

    func extractedLayout(for fileID: UUID) -> ExtractedLayout? {
        extractedLayouts[fileID]
    }

    func add(urls: [URL], kind: ImportFileKind, projectID: UUID) {
        for url in urls {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            files.append(ImportFile(projectID: projectID, url: url, kind: kind, fileSize: size ?? 0))
        }
        startWorkerIfNeeded()
    }

    /// Records a file that was already read elsewhere, such as the mock project seeded at launch.
    func addFinished(_ file: ImportFile, legend: Legend?, layout: ExtractedLayout?) {
        files.append(file)
        legendsByFile[file.id] = legend
        extractedLayouts[file.id] = layout
    }

    func remove(fileID: UUID) {
        let wasCurrent = currentFileID == fileID
        files.removeAll { $0.id == fileID }
        forgetResults(of: [fileID])
        if wasCurrent { restartWorker() }
    }

    func retry(fileID: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        forgetResults(of: [fileID])
        files[index].state = .waiting
        startWorkerIfNeeded()
    }

    func cancel(projectID: UUID) {
        var cancelledCurrent = false
        for index in files.indices where files[index].projectID == projectID {
            switch files[index].state {
            case .waiting, .reading:
                cancelledCurrent = cancelledCurrent || files[index].id == currentFileID
                files[index].state = .cancelled
            case .done, .failed, .cancelled:
                break
            }
        }
        if cancelledCurrent { restartWorker() }
    }

    func removeAll(projectID: UUID) {
        let ids = Set(files(for: projectID).map(\.id))
        let removedCurrent = currentFileID.map(ids.contains) ?? false
        forgetResults(of: ids)
        files.removeAll { ids.contains($0.id) }
        if removedCurrent { restartWorker() }
    }

    private func forgetResults(of ids: some Collection<UUID>) {
        for id in ids {
            legendsByFile.removeValue(forKey: id)
            extractedLayouts.removeValue(forKey: id)
        }
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, !Task.isCancelled, let file = self.nextWaitingFile() {
                self.currentFileID = file.id
                await self.read(file)
            }
            self?.finishWorker()
        }
    }

    private func finishWorker() {
        currentFileID = nil
        worker = nil
    }

    private func restartWorker() {
        worker?.cancel()
        worker = nil
        currentFileID = nil
        startWorkerIfNeeded()
    }

    private func nextWaitingFile() -> ImportFile? {
        files.first { $0.kind == .legend && $0.state == .waiting }
            ?? files.first { $0.state == .waiting }
    }

    private func read(_ file: ImportFile) async {
        setState(.reading(progress: nil), for: file.id)
        do {
            switch file.kind {
            case .legend:
                let legend = try await readLegend(file)
                guard isCurrent(file.id) else { return }
                legendsByFile[file.id] = legend
                setState(.done(booths: 0, doors: 0), for: file.id)
            case .floorPlan:
                let layout = try await readPlan(file)
                guard isCurrent(file.id) else { return }
                extractedLayouts[file.id] = layout
                setState(.done(booths: layout.booths, doors: layout.doors), for: file.id)
            }
        } catch {
            guard isCurrent(file.id) else { return }
            let noun = file.kind == .legend ? "legend" : "plan"
            setState(.failed(message: "Couldn't read this \(noun)"), for: file.id)
        }
    }

    private func readLegend(_ file: ImportFile) async throws -> Legend {
        let page = try pdf.renderFirstPage(of: file.url)
        return try await reader.readLegend(page)
    }

    private func readPlan(_ file: ImportFile) async throws -> ExtractedLayout {
        let readLegendFile = files(for: file.projectID).first { $0.kind == .legend && legendsByFile[$0.id] != nil }
        guard let legendFile = readLegendFile, let legend = legend(for: file.projectID) else {
            throw PDFImportError.unreadable
        }
        let legendPage = try pdf.renderFirstPage(of: legendFile.url)
        let page = try pdf.renderFirstPage(of: file.url)
        let fileID = file.id
        return try await reader.readPlan(
            page,
            legendPage: legendPage,
            legend: legend,
            name: file.url.deletingPathExtension().lastPathComponent
        ) { [weak self] progress in
            Task { @MainActor in self?.reportProgress(progress, for: fileID) }
        }
    }

    private func reportProgress(_ progress: Double, for fileID: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }),
              case .reading = files[index].state else { return }
        files[index].state = .reading(progress: progress)
    }

    /// False once the file was removed or cancelled while the reader was still running.
    private func isCurrent(_ fileID: UUID) -> Bool {
        guard let file = files.first(where: { $0.id == fileID }) else { return false }
        if case .reading = file.state { return true }
        return false
    }

    private func setState(_ state: ImportFileState, for fileID: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        files[index].state = state
    }
}

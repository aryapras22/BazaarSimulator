import CoreGraphics
import Foundation
import Observation

/// Reads one file at a time, legends first, so only one reading pass is in memory at once.
@Observable
@MainActor
final class ImportQueue: ImportQueueing {
    private(set) var files: [ImportFile] = []
    private var legendsByFile: [UUID: Legend] = [:]
    private var extractedLayouts: [UUID: ExtractedLayout] = [:]
    private var logEntries: [ImportLogEntry] = []

    private let pdf: any PDFImporting
    private let reader: any FloorPlanReading
    private var worker: Task<Void, Never>?
    private var currentFileID: UUID?
    private let logLimit: Int

    init(pdf: any PDFImporting, reader: any FloorPlanReading, logLimit: Int = 2000) {
        self.pdf = pdf
        self.reader = reader
        self.logLimit = logLimit
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

    func logEntries(for projectID: UUID) -> [ImportLogEntry] {
        logEntries.filter { $0.projectID == projectID }
    }

    func add(urls: [URL], kind: ImportFileKind, projectID: UUID) {
        for url in urls {
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            let file = ImportFile(projectID: projectID, url: url, kind: kind, fileSize: size ?? 0)
            files.append(file)
            log("Picked, \(file.fileSize.formatted(.byteCount(style: .file)))", for: file)
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
        if let file = files.first(where: { $0.id == fileID }) { log("Removed", for: file) }
        files.removeAll { $0.id == fileID }
        forgetResults(of: [fileID])
        if wasCurrent { restartWorker() }
    }

    func retry(fileID: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        forgetResults(of: [fileID])
        files[index].state = .waiting
        log("Queued again", for: files[index])
        startWorkerIfNeeded()
    }

    func cancel(projectID: UUID) {
        var cancelledCurrent = false
        for index in files.indices where files[index].projectID == projectID {
            switch files[index].state {
            case .waiting, .reading:
                cancelledCurrent = cancelledCurrent || files[index].id == currentFileID
                files[index].state = .cancelled
                log("Cancelled", for: files[index])
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
        logEntries.removeAll { $0.projectID == projectID }
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
        // Files from the file picker are sandbox-scoped and unreadable without this; dropped files return false.
        let scoped = file.url.startAccessingSecurityScopedResource()
        defer { if scoped { file.url.stopAccessingSecurityScopedResource() } }
        setState(.reading(progress: nil, step: "Rendering PDF..."), for: file.id)
        log("Started reading", for: file)
        do {
            switch file.kind {
            case .legend:
                let legend = try await readLegend(file)
                guard isCurrent(file.id) else { return }
                legendsByFile[file.id] = legend
                setState(.done(booths: 0, doors: 0), for: file.id)
                let names = legend.entries.map(\.name).joined(separator: ", ")
                log("Legend read: \(legend.entries.count) entries (\(names))", for: file)
            case .floorPlan:
                var layout = try await readPlan(file)
                guard isCurrent(file.id) else { return }
                // Project setup finds a plan's layout by its file's ID, so Edit does nothing when they differ.
                layout.layout.id = file.id
                extractedLayouts[file.id] = layout
                setState(.done(booths: layout.booths, doors: layout.doors), for: file.id)
                log("Done: \(layout.booths) booths, \(layout.doors) doors", for: file)
            }
        } catch {
            guard isCurrent(file.id) else { return }
            setState(.failed(message: Self.failureMessage(for: error, kind: file.kind)), for: file.id)
            log("Failed: \(error)", for: file, severity: .failure)
        }
    }

    private static func failureMessage(for error: Error, kind: ImportFileKind) -> String {
        switch error {
        case PDFImportError.unreadable:
            return "Can't open this PDF. It may be damaged or password-protected."
        case PDFImportError.noPermission:
            return "No permission to read this file. Try adding it again, or move it to another folder."
        case FloorPlanReadingError.noLegend:
            return "No legend has been read yet. Add a legend, then retry."
        case FloorPlanReadingError.noBooths:
            return "No booths found. Check that this is a floor plan with booths drawn on it."
        default:
            let noun = kind == .legend ? "legend" : "plan"
            return "Something went wrong while reading this \(noun). Try again."
        }
    }

    private func readLegend(_ file: ImportFile) async throws -> Legend {
        let page = try renderPage(of: file.url, loggedFor: file)
        setState(.reading(progress: nil, step: "Reading legend..."), for: file.id)
        log("Reading legend entries", for: file)
        return try await reader.readLegend(page)
    }

    private func readPlan(_ file: ImportFile) async throws -> ExtractedLayout {
        let readLegends = files(for: file.projectID).compactMap { legendFile -> (file: ImportFile, legend: Legend)? in
            guard legendFile.kind == .legend, let legend = legendsByFile[legendFile.id] else { return nil }
            return (legendFile, legend)
        }
        guard !readLegends.isEmpty else {
            log("No legend has been read for this project", for: file, severity: .failure)
            throw FloorPlanReadingError.noLegend
        }
        let page = try renderPage(of: file.url, loggedFor: file)
        setState(.reading(progress: 0.03, step: "Matching legend..."), for: file.id)
        let match = LegendMatcher.bestMatchIndex(for: page, among: readLegends.map(\.legend))
        let chosen = readLegends[match ?? 0]
        let legendName = chosen.file.url.lastPathComponent
        log(match == nil ? "No legend colours found, using \(legendName)" : "Matched \(legendName)", for: file)
        let legendScoped = chosen.file.url.startAccessingSecurityScopedResource()
        defer { if legendScoped { chosen.file.url.stopAccessingSecurityScopedResource() } }
        let legendPage = try renderPage(of: chosen.file.url, loggedFor: file)
        setState(.reading(progress: 0.06, step: "Reading plan..."), for: file.id)
        log("Reading plan", for: file)
        return try await reader.readPlan(
            page,
            legendPage: legendPage,
            legend: chosen.legend,
            name: file.url.deletingPathExtension().lastPathComponent
        ) { [weak self] event in
            self?.handle(event, for: file)
        }
    }

    private func renderPage(of url: URL, loggedFor file: ImportFile) throws -> CGImage {
        let page = try pdf.renderFirstPage(of: url)
        log("Rendered \(url.lastPathComponent), \(page.width) x \(page.height) px", for: file)
        return page
    }

    /// Dropped once the file was removed or cancelled, so a stopped read leaves nothing after its last log line.
    private func handle(_ event: PlanReadingEvent, for file: ImportFile) {
        guard isCurrent(file.id) else { return }
        switch event {
        case .progress(let progress, let step):
            reportProgress(progress, step: step, for: file)
        case .note(let note):
            log(note, for: file)
        }
    }

    private func reportProgress(_ progress: Double, step: String?, for file: ImportFile) {
        guard let index = files.firstIndex(where: { $0.id == file.id }),
              case .reading(let previous, let previousStep) = files[index].state else { return }
        if let previous, progress < previous { return }
        files[index].state = .reading(progress: progress, step: step ?? previousStep)
        let quarter = Int(progress * 4)
        if quarter > Int((previous ?? 0) * 4) { log("Extractor at \(quarter * 25)%", for: file) }
    }

    private func log(_ message: String, for file: ImportFile, severity: ImportLogEntry.Severity = .info) {
        logEntries.append(ImportLogEntry(
            date: .now,
            projectID: file.projectID,
            fileName: file.url.lastPathComponent,
            message: message,
            severity: severity
        ))
        if logEntries.count > logLimit { logEntries.removeFirst(logEntries.count - logLimit) }
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

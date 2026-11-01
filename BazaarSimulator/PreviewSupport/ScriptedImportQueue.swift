import Foundation
import Observation

/// Stands in for the real queue until the backend PR swaps AppServices to the real one,
/// then moves to Tests/Support/.
@Observable
@MainActor
final class ScriptedImportQueue: ImportQueueing {
    private(set) var files: [ImportFile] = []
    private var legendsByFile: [UUID: Legend] = [:]
    private var extractedLayouts: [UUID: ExtractedLayout] = [:]

    var failingFileNames: Set<String> = []
    var isSynchronous: Bool = false

    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    init(isSynchronous: Bool = false) {
        self.isSynchronous = isSynchronous
    }

    func files(for projectID: UUID) -> [ImportFile] {
        files.filter { $0.projectID == projectID }
    }

    func legend(for projectID: UUID) -> Legend? {
        // Deduplicating categories by name across legend files is a backend decision.
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
            let fileSize = fileSize(for: url)
            let file = ImportFile(
                projectID: projectID,
                url: url,
                kind: kind,
                state: .waiting,
                fileSize: fileSize
            )
            files.append(file)

            if isSynchronous {
                processFileSynchronously(file)
            } else {
                startAsyncProcessing(for: file)
            }
        }
    }

    func insert(_ file: ImportFile) {
        files.append(file)
    }

    func remove(fileID: UUID) {
        activeTasks[fileID]?.cancel()
        activeTasks.removeValue(forKey: fileID)
        files.removeAll { $0.id == fileID }
        legendsByFile.removeValue(forKey: fileID)
        extractedLayouts.removeValue(forKey: fileID)
    }

    func cancel(projectID: UUID) {
        for index in files.indices where files[index].projectID == projectID {
            switch files[index].state {
            case .waiting, .reading:
                activeTasks[files[index].id]?.cancel()
                activeTasks.removeValue(forKey: files[index].id)
                files[index].state = .cancelled
            case .done, .failed, .cancelled:
                break
            }
        }
    }

    func retry(fileID: UUID) {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        legendsByFile.removeValue(forKey: fileID)
        extractedLayouts.removeValue(forKey: fileID)
        files[index].state = .waiting
        let file = files[index]
        if isSynchronous {
            processFileSynchronously(file)
        } else {
            startAsyncProcessing(for: file)
        }
    }

    func removeAll(projectID: UUID) {
        let matchingIDs = files.filter { $0.projectID == projectID }.map(\.id)
        for id in matchingIDs {
            activeTasks[id]?.cancel()
            activeTasks.removeValue(forKey: id)
            legendsByFile.removeValue(forKey: id)
            extractedLayouts.removeValue(forKey: id)
        }
        files.removeAll { $0.projectID == projectID }
    }

    func failFile(named name: String) {
        failingFileNames.insert(name)
    }

    private func fileSize(for url: URL) -> Int64 {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            return size
        }
        return 2_516_582 // Default simulated 2.4 MB
    }

    private func processFileSynchronously(_ file: ImportFile) {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return }

        if failingFileNames.contains(file.url.lastPathComponent) {
            files[index].state = .failed(message: "Couldn't read this plan")
            return
        }

        if file.kind == .legend {
            let defaultLegend = Legend(entries: [
                LegendEntry(name: "FNB", color: LegendColor(red: 222 / 255.0, green: 42 / 255.0, blue: 42 / 255.0)),
                LegendEntry(name: "Fashion", color: LegendColor(red: 42 / 255.0, green: 222 / 255.0, blue: 49 / 255.0)),
                LegendEntry(
                    name: "Lifestyle & Hobbies",
                    color: LegendColor(red: 244 / 255.0, green: 220 / 255.0, blue: 48 / 255.0)
                )
            ])
            legendsByFile[file.id] = defaultLegend
            files[index].state = .done(booths: 0, doors: 0)
        } else {
            files[index].state = .done(booths: 66, doors: 3)
            extractedLayouts[file.id] = ExtractedLayout(
                id: file.id,
                name: file.url.deletingPathExtension().lastPathComponent,
                sizeInMetres: LayoutDimensions(width: 70.1, height: 84.2),
                booths: 66,
                doors: 3
            )
        }
    }

    private func startAsyncProcessing(for file: ImportFile) {
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            guard let index = self.files.firstIndex(where: { $0.id == file.id }) else { return }

            self.files[index].state = .reading(progress: 0.1)

            if self.failingFileNames.contains(file.url.lastPathComponent) {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                if let idx = self.files.firstIndex(where: { $0.id == file.id }) {
                    self.files[idx].state = .failed(message: "Couldn't read this plan")
                }
                return
            }

            for step in [0.35, 0.70, 0.95] {
                try? await Task.sleep(nanoseconds: 80_000_000)
                if Task.isCancelled { return }
                if let idx = self.files.firstIndex(where: { $0.id == file.id }) {
                    self.files[idx].state = .reading(progress: step)
                }
            }

            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }

            self.processFileSynchronously(file)
        }
        activeTasks[file.id] = task
    }
}

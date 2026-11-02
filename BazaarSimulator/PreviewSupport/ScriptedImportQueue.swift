import Foundation
import Observation
import simd

/// Stands in for the real queue until the backend PR swaps AppServices to the real one,
/// then moves to Tests/Support/.
@Observable
@MainActor
final class ScriptedImportQueue: ImportQueueing {
    var mockLayoutFileNames: [String] = [
        "annyeong-market-layout",
        "beyond-market-layout"
    ]

    private(set) var files: [ImportFile] = []
    private var legendsByFile: [UUID: Legend] = [:]
    private var extractedLayouts: [UUID: ExtractedLayout] = [:]

    var failingFileNames: Set<String> = []
    var isSynchronous: Bool = false

    private var worker: Task<Void, Never>?
    private var currentFileID: UUID?

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
            }
        }
        if !isSynchronous {
            startWorkerIfNeeded()
        }
    }

    func insert(_ file: ImportFile) {
        files.append(file)
    }

    func remove(fileID: UUID) {
        let wasCurrent = (currentFileID == fileID)
        files.removeAll { $0.id == fileID }
        legendsByFile.removeValue(forKey: fileID)
        extractedLayouts.removeValue(forKey: fileID)
        if wasCurrent {
            cancelCurrentFileAndRestart()
        }
    }

    func cancel(projectID: UUID) {
        var cancelledCurrent = false
        for index in files.indices where files[index].projectID == projectID {
            switch files[index].state {
            case .waiting, .reading:
                if files[index].id == currentFileID {
                    cancelledCurrent = true
                }
                files[index].state = .cancelled
            case .done, .failed, .cancelled:
                break
            }
        }
        if cancelledCurrent {
            cancelCurrentFileAndRestart()
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
            startWorkerIfNeeded()
        }
    }

    func removeAll(projectID: UUID) {
        let matchingIDs = Set(files.filter { $0.projectID == projectID }.map(\.id))
        let removedCurrent = currentFileID.map { matchingIDs.contains($0) } ?? false
        for id in matchingIDs {
            legendsByFile.removeValue(forKey: id)
            extractedLayouts.removeValue(forKey: id)
        }
        files.removeAll { $0.projectID == projectID }
        if removedCurrent {
            cancelCurrentFileAndRestart()
        }
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
            let message = file.kind == .legend ? "Couldn't read this legend" : "Couldn't read this plan"
            files[index].state = .failed(message: message)
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
            if let extracted = buildExtractedLayout(for: file) {
                extractedLayouts[file.id] = extracted
                files[index].state = .done(booths: extracted.booths, doors: extracted.doors)
            } else {
                files[index].state = .failed(message: "Couldn't load the mock layout")
            }
        }
    }

    private func buildExtractedLayout(for file: ImportFile) -> ExtractedLayout? {
        guard !mockLayoutFileNames.isEmpty else { return nil }
        let projectPlans = files(for: file.projectID).filter { $0.kind == .floorPlan }
        let planIndex = projectPlans.firstIndex { $0.id == file.id } ?? 0
        let mockName = mockLayoutFileNames[planIndex % mockLayoutFileNames.count]
        let projectLegend = legend(for: file.projectID) ?? Legend()
        let fileName = file.url.deletingPathExtension().lastPathComponent

        guard let dto = try? MockDataStore.load(BazaarLayoutDTO.self, from: mockName) else {
            return nil
        }
        let mapped = MockLayoutMapper.layout(
            from: dto,
            legend: projectLegend,
            id: file.id,
            nameOverride: fileName
        )
        return ExtractedLayout(layout: mapped)
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }
        worker = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, let file = self.nextWaitingFile() {
                self.currentFileID = file.id
                await self.readAsync(file)
            }
            if !Task.isCancelled {
                self?.currentFileID = nil
                self?.worker = nil
            }
        }
    }

    private func cancelCurrentFileAndRestart() {
        worker?.cancel()
        worker = nil
        currentFileID = nil
        startWorkerIfNeeded()
    }

    private func nextWaitingFile() -> ImportFile? {
        files.first { $0.kind == .legend && $0.state == .waiting }
            ?? files.first { $0.state == .waiting }
    }

    private func readAsync(_ file: ImportFile) async {
        guard let index = files.firstIndex(where: { $0.id == file.id }) else { return }

        files[index].state = .reading(progress: 0.1)

        if failingFileNames.contains(file.url.lastPathComponent) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
            if let idx = files.firstIndex(where: { $0.id == file.id }) {
                let message = file.kind == .legend
                    ? "Couldn't read this legend"
                    : "Couldn't read this plan"
                files[idx].state = .failed(message: message)
            }
            return
        }

        for step in [0.35, 0.70, 0.95] {
            try? await Task.sleep(nanoseconds: 80_000_000)
            if Task.isCancelled { return }
            if let idx = files.firstIndex(where: { $0.id == file.id }) {
                files[idx].state = .reading(progress: step)
            }
        }

        try? await Task.sleep(nanoseconds: 80_000_000)
        if Task.isCancelled { return }

        processFileSynchronously(file)
    }
}

import CryptoKit
import Foundation

@MainActor
final class AppServices {
    let importQueue: any ImportQueueing
    let projectSession: any ProjectSessionProtocol
    let analysisService: any AnalysisServiceProtocol
    let presetCatalog: PresetCatalog
    let initialDestination: AppDestination

    init(
        importQueue: (any ImportQueueing)? = nil,
        projectSession: (any ProjectSessionProtocol)? = nil,
        analysisService: (any AnalysisServiceProtocol)? = nil,
        presetCatalog: PresetCatalog? = nil,
        seedsMockProject: Bool = false
    ) {
        let session = projectSession ?? ProjectSession()
        let queue = importQueue ?? ImportQueue(pdf: PDFImportService(), reader: ExtractorFloorPlanReader())
        self.importQueue = queue
        self.projectSession = session
        self.analysisService = analysisService ?? AnalysisService()
        self.presetCatalog = presetCatalog ?? PresetCatalog.bundled()

        // Each seed is read by its own scripted queue so that projects created afterwards go through the extractor.
        // Its finished files are copied into the app's queue, which is where project setup reads them.
        // The last seed stays selected.
        if seedsMockProject {
            var projectID = UUID()
            for seed in Self.mockSeeds {
                let scripted = ScriptedImportQueue(isSynchronous: true)
                scripted.mockLayoutFileNames = seed.layoutNames
                projectID = Self.seedMockProject(
                    seed,
                    in: session,
                    importQueue: scripted
                )
                if let readQueue = queue as? ImportQueue {
                    Self.copyFinishedFiles(of: projectID, from: scripted, into: readQueue)
                }
            }
            initialDestination = .setup(projectID: projectID)
        } else {
            initialDestination = .empty
        }
    }

    private struct MockSeed {
        let name: String
        let layoutNames: [String]
        let planNames: [String]
    }

    /// `planNames` are the file names users see; the scripted queue loads `layoutNames` by position.
    private static let mockSeeds: [MockSeed] = [
        MockSeed(
            name: "Lantern Night Market",
            layoutNames: ["annyeong-market-layout", "beyond-market-layout", "lantern-festival-layout"],
            planNames: ["Seoul Food Week", "Spooky Weekend", "Mid-Autumn Lantern Fest"]
        ),
        MockSeed(
            name: "Riverside Weekend Bazaar",
            layoutNames: [
                "more-market-i-layout",
                "more-market-iii-layout",
                "more-market-iv-layout",
                "more-market-v-layout",
                "more-market-viii-layout"
            ],
            planNames: ["North Atrium", "Garden Court", "East Annex", "Central Atrium", "South Atrium"]
        )
    ]

    private static func seedFingerprint(for seed: MockSeed, in bundle: Bundle = .main) -> String {
        var hasher = SHA256()

        func updateLength(_ count: Int) {
            var length = UInt64(count).bigEndian
            withUnsafeBytes(of: &length) { hasher.update(bufferPointer: $0) }
        }

        func updateData(_ data: Data) {
            updateLength(data.count)
            hasher.update(data: data)
        }

        func updateString(_ string: String) {
            updateData(Data(string.utf8))
        }

        updateLength(seed.layoutNames.count)
        for fileName in seed.layoutNames {
            updateString(fileName)
            if let rawBytes = try? MockDataStore.rawData(from: fileName, in: bundle) {
                hasher.update(data: Data([1]))
                updateData(rawBytes)
            } else {
                hasher.update(data: Data([0]))
            }
        }

        updateLength(seed.planNames.count)
        for planName in seed.planNames {
            updateString(planName)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func seedMockProject(
        _ seed: MockSeed,
        in session: any ProjectSessionProtocol,
        importQueue: ScriptedImportQueue
    ) -> UUID {
        // A project saved by an earlier launch keeps its ID, so its saved analyses stay with it.
        let project = session.project(named: seed.name) ?? session.createProject(named: seed.name)
        importQueue.add(
            urls: [URL(fileURLWithPath: "/mock/legend.pdf")],
            kind: .legend,
            projectID: project.id
        )
        importQueue.add(
            urls: seed.planNames.map { URL(fileURLWithPath: "/mock/\($0).pdf") },
            kind: .floorPlan,
            projectID: project.id
        )

        let fingerprint = seedFingerprint(for: seed)
        let shouldWriteSeed: Bool = switch session.draft(for: project.id) {
        case nil:
            true
        case .some(let existing):
            existing.seedFingerprint != nil && existing.seedFingerprint != fingerprint
        }

        if shouldWriteSeed {
            let floorPlanFiles = importQueue.files(for: project.id).filter { $0.kind == .floorPlan }
            let layouts = floorPlanFiles.compactMap { importQueue.extractedLayout(for: $0.id)?.layout }
            let legend = importQueue.legend(for: project.id) ?? Legend()
            let draft = ProjectDraft(name: project.name, legend: legend, layouts: layouts)
            session.setSeededDraft(draft, fingerprint: fingerprint, for: project.id)
        }
        session.selectProject(id: project.id)
        return project.id
    }

    private static func copyFinishedFiles(
        of projectID: UUID,
        from scripted: ScriptedImportQueue,
        into queue: ImportQueue
    ) {
        for file in scripted.files(for: projectID) {
            queue.addFinished(
                file,
                legend: file.kind == .legend ? scripted.legend(for: projectID) : nil,
                layout: scripted.extractedLayout(for: file.id)
            )
        }
    }
}

import Foundation

@MainActor
final class AppServices {
    let importQueue: any ImportQueueing
    let projectSession: any ProjectSessionProtocol
    let initialDestination: AppDestination

    init(
        importQueue: (any ImportQueueing)? = nil,
        projectSession: (any ProjectSessionProtocol)? = nil,
        seedsMockProject: Bool = false
    ) {
        let session = projectSession ?? ProjectSession()
        let queue = importQueue ?? ImportQueue(pdf: PDFImportService(), reader: ExtractorFloorPlanReader())
        self.importQueue = queue
        self.projectSession = session

        // Each seed is read by its own scripted queue so that projects created afterwards go through the extractor.
        // Its finished files are copied into the app's queue, which is where project setup reads them.
        // The last seed stays selected.
        if seedsMockProject {
            var projectID = UUID()
            for seed in Self.mockSeeds {
                let scripted = ScriptedImportQueue(isSynchronous: true)
                scripted.mockLayoutFileNames = seed.layoutNames
                projectID = Self.seedMockProject(
                    named: seed.name,
                    layoutNames: seed.layoutNames,
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

    private static let mockSeeds: [(name: String, layoutNames: [String])] = [
        ("More Market", ["more-market-iii-layout", "more-market-vi-layout"]),
        ("Annyeong Market", ["annyeong-market-layout", "beyond-market-layout"])
    ]

    private static func seedMockProject(
        named name: String,
        layoutNames: [String],
        in session: any ProjectSessionProtocol,
        importQueue: ScriptedImportQueue
    ) -> UUID {
        let project = session.createProject(named: name)
        importQueue.add(
            urls: [URL(fileURLWithPath: "/mock/legend.pdf")],
            kind: .legend,
            projectID: project.id
        )
        importQueue.add(
            urls: layoutNames.map { URL(fileURLWithPath: "/mock/\($0).pdf") },
            kind: .floorPlan,
            projectID: project.id
        )

        let floorPlanFiles = importQueue.files(for: project.id).filter { $0.kind == .floorPlan }
        let layouts = floorPlanFiles.compactMap { importQueue.extractedLayout(for: $0.id)?.layout }
        let legend = importQueue.legend(for: project.id) ?? Legend()
        let draft = ProjectDraft(name: project.name, legend: legend, layouts: layouts)
        session.setDraft(draft, for: project.id)
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

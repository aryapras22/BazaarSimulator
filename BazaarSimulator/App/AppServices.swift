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

        // The seed is read by its own scripted queue so that projects created afterwards go through the extractor.
        // Its finished files are copied into the app's queue, which is where project setup reads them.
        if seedsMockProject {
            let scripted = ScriptedImportQueue(isSynchronous: true)
            let projectID = Self.seedMockProject(in: session, importQueue: scripted)
            if let readQueue = queue as? ImportQueue {
                Self.copyFinishedFiles(of: projectID, from: scripted, into: readQueue)
            }
            initialDestination = .analysis(projectID: projectID)
        } else {
            initialDestination = .empty
        }
    }

    private static func seedMockProject(
        in session: any ProjectSessionProtocol,
        importQueue: ScriptedImportQueue
    ) -> UUID {
        let project = session.createProject(named: "Annyeong Market")
        importQueue.add(
            urls: [URL(fileURLWithPath: "/mock/legend.pdf")],
            kind: .legend,
            projectID: project.id
        )
        importQueue.add(
            urls: [
                URL(fileURLWithPath: "/mock/annyeong-market-layout.pdf"),
                URL(fileURLWithPath: "/mock/beyond-market-layout.pdf")
            ],
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

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
        self.importQueue = importQueue ?? ImportQueue(pdf: PDFImportService(), reader: ExtractorFloorPlanReader())
        self.projectSession = session

        // The seed has its own scripted queue so that projects created afterwards are read by the real one.
        if seedsMockProject {
            let projectID = Self.seedMockProject(in: session, importQueue: ScriptedImportQueue(isSynchronous: true))
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
}

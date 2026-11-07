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
        let queue = importQueue ?? ScriptedImportQueue()
        let session = projectSession ?? ProjectSession()
        self.importQueue = queue
        self.projectSession = session
        self.analysisService = analysisService ?? AnalysisService()
        self.presetCatalog = presetCatalog ?? PresetCatalog.bundled()

        if seedsMockProject, let scriptedQueue = queue as? ScriptedImportQueue {
            let projectID = Self.seedMockProject(in: session, importQueue: scriptedQueue)
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
        let wasSynchronous = importQueue.isSynchronous
        importQueue.isSynchronous = true
        defer { importQueue.isSynchronous = wasSynchronous }

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

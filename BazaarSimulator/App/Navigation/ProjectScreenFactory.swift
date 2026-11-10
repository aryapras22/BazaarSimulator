import Foundation

@MainActor
final class ProjectScreenFactory {
    private let services: AppServices
    private let router: AppRouter
    private var setupViewModels: [UUID: ProjectSetupViewModel] = [:]
    private var layoutEditorViewModels: [UUID: LayoutEditorViewModel] = [:]

    init(services: AppServices, router: AppRouter) {
        self.services = services
        self.router = router
    }

    func makeLibraryViewModel() -> ProjectLibraryViewModel {
        ProjectLibraryViewModel(
            session: services.projectSession,
            onOpenProject: { [weak router, weak session = services.projectSession] id in
                if let draft = session?.draft(for: id), !draft.layouts.isEmpty {
                    router?.showAnalysis(projectID: id)
                } else {
                    router?.showSetup(projectID: id)
                }
            }
        )
    }

    func makeSetupViewModel(projectID: UUID) -> ProjectSetupViewModel {
        if let existing = setupViewModels[projectID] {
            return existing
        }
        let created = ProjectSetupViewModel(
            projectID: projectID,
            session: services.projectSession,
            importQueue: services.importQueue,
            onContinue: { [weak router] id in
                router?.showAnalysis(projectID: id)
            },
            onEdit: { [weak router] id in
                router?.showEditor(projectID: id)
            }
        )
        setupViewModels[projectID] = created
        return created
    }

    func makeLayoutEditorViewModel(projectID: UUID) -> LayoutEditorViewModel {
        if let existing = layoutEditorViewModels[projectID] {
            return existing
        }
        let created = LayoutEditorViewModel(
            projectID: projectID,
            session: services.projectSession,
            onBack: { [weak router] in
                router?.showAnalysis(projectID: projectID)
            }
        )
        layoutEditorViewModels[projectID] = created
        return created
    }

    func makeSimulationViewModel(projectID: UUID) -> SimulationViewModel {
        let session = services.projectSession
        let layouts = session.draft(for: projectID)?.layouts ?? []
        let activeID = session.activeLayoutID(for: projectID)
        let layout = (activeID.flatMap { session.layout(id: $0, in: projectID) })
            ?? layouts.first
            ?? PreviewLayouts.beyond()
        let savedResult = session.simulationResult(for: layout.id, in: projectID)
        let settings = session.parameters(for: projectID).toSimulationSettings()
        return SimulationViewModel(
            layout: layout,
            availableLayouts: layouts,
            savedResult: savedResult,
            engine: SimulationEngine(layout: layout, settings: settings),
            onLayoutSelected: { [weak session] selectedID in
                session?.setActiveLayoutID(selectedID, for: projectID)
            },
            resultProvider: { [weak session] layoutID in
                session?.simulationResult(for: layoutID, in: projectID)
            }
        )
    }
}

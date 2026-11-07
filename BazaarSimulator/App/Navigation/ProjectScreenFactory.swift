import Foundation

@MainActor
final class ProjectScreenFactory {
    private let services: AppServices
    private let router: AppRouter
    private var setupViewModels: [UUID: ProjectSetupViewModel] = [:]
    private var layoutEditorViewModels: [UUID: LayoutEditorViewModel] = [:]
    private var dashboardViewModels: [UUID: DashboardViewModel] = [:]

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
                // Parameters come first. The analysis opens when they are applied.
                router?.showParameters(projectID: id)
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

    func makeDashboardViewModel(projectID: UUID) -> DashboardViewModel {
        if let existing = dashboardViewModels[projectID] {
            return existing
        }
        let session = services.projectSession
        /// Layout 1 and Layout 2 on the compare page are the project's first two layouts.
        func open(_ layout: LayoutID, then show: @escaping (UUID) -> Void) {
            let layouts = session.draft(for: projectID)?.layouts ?? []
            if layout.rawValue - 1 < layouts.count {
                session.setActiveLayoutID(layouts[layout.rawValue - 1].id, for: projectID)
            }
            show(projectID)
        }
        let created = DashboardViewModel(
            projectID: projectID,
            session: session,
            analysisService: services.analysisService,
            catalog: services.presetCatalog,
            onBack: { [weak router] in
                router?.showSetup(projectID: projectID)
            },
            onSimulate: { [weak router] layout in
                router?.requestSimulation(projectID: projectID, layout: layout)
            },
            onEdit: { [weak router] layout in
                open(layout) { router?.showEditor(projectID: $0) }
            }
        )
        dashboardViewModels[projectID] = created
        return created
    }

    func makeParametersViewModel(
        projectID: UUID,
        onClose: @escaping () -> Void,
        onApply: (() -> Void)? = nil
    ) -> ParametersViewModel {
        ParametersViewModel(
            projectID: projectID,
            session: services.projectSession,
            catalog: services.presetCatalog,
            onClose: onClose,
            onApply: onApply
        )
    }
}

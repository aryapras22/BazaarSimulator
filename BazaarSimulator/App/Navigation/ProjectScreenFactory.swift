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

    func makeParametersViewModel(projectID: UUID, onClose: @escaping () -> Void) -> ParametersViewModel {
        ParametersViewModel(
            projectID: projectID,
            session: services.projectSession,
            catalog: PresetCatalog.bundled(),
            onClose: onClose
        )
    }
}

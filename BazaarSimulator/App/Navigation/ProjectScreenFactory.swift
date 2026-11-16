import Foundation

@MainActor
final class ProjectScreenFactory {
    private let services: AppServices
    private let router: AppRouter
    private var setupViewModels: [UUID: ProjectSetupViewModel] = [:]
    private var layoutEditorViewModels: [UUID: LayoutEditorViewModel] = [:]
    private var dashboardViewModels: [UUID: DashboardViewModel] = [:]
    private var savedDashboardViewModels: [UUID: DashboardViewModel] = [:]

    init(services: AppServices, router: AppRouter) {
        self.services = services
        self.router = router
    }

    func makeLibraryViewModel() -> ProjectLibraryViewModel {
        ProjectLibraryViewModel(
            session: services.projectSession,
            destination: { [weak router] in router?.destination ?? .empty },
            // A project folder opens its setup page. Its saved runs sit inside it.
            onOpenProject: { [weak router] id in router?.showSetup(projectID: id) },
            onOpenAnalysis: { [weak router] projectID, analysisID in
                router?.showSavedAnalysis(projectID: projectID, analysisID: analysisID)
            },
            onOpenLatestAnalysis: { [weak router] id in router?.showAnalysis(projectID: id) },
            onDeleteProject: { [weak self] id in self?.deleteProject(id: id) }
        )
    }

    /// Removes a project with everything it holds: its files in the import queue, its saved screens, its results,
    /// and its saved analyses. If it was open, the app moves on to the next project, or to the empty workspace.
    private func deleteProject(id: UUID) {
        let session = services.projectSession
        let wasOpen = router.destination.projectID == id
        let position = session.projects.firstIndex { $0.id == id } ?? 0

        services.importQueue.removeAll(projectID: id)
        setupViewModels[id] = nil
        layoutEditorViewModels[id] = nil
        dashboardViewModels[id] = nil
        savedDashboardViewModels = savedDashboardViewModels.filter { $0.value.projectID != id }
        if router.parametersProjectID == id { router.dismissParameters() }
        session.deleteProject(id: id)

        guard wasOpen else { return }
        let remaining = session.projects
        if let next = remaining.indices.contains(position) ? remaining[position] : remaining.last {
            session.selectProject(id: next.id)
            router.showSetup(projectID: next.id)
        } else {
            router.showEmpty()
        }
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
                router?.closeEditor(projectID: projectID)
            }
        )
        layoutEditorViewModels[projectID] = created
        return created
    }

    /// One view model for each saved run. The app root builds its screens again whenever it refreshes, for example
    /// when a simulator window is requested, and a new view model would start over on the loading page.
    func makeSavedDashboardViewModel(projectID: UUID, analysisID: UUID) -> DashboardViewModel {
        if let existing = savedDashboardViewModels[analysisID] {
            return existing
        }
        let created = DashboardViewModel(
            projectID: projectID,
            source: .saved(analysisID),
            session: services.projectSession,
            analysisService: services.analysisService,
            catalog: services.presetCatalog,
            onBack: { [weak router] in router?.showSetup(projectID: projectID) },
            onSimulate: { [weak router] layout in
                router?.requestSimulation(projectID: projectID, layout: layout, analysisID: analysisID)
            }
        )
        savedDashboardViewModels[analysisID] = created
        return created
    }

    func makeDashboardViewModel(projectID: UUID) -> DashboardViewModel {
        if let existing = dashboardViewModels[projectID] {
            return existing
        }
        let session = services.projectSession
        /// Layout 1 and Layout 2 on the compare page are the layouts the project compares.
        func open(_ layout: LayoutID, then show: @escaping (UUID) -> Void) {
            let layouts = session.comparedLayouts(for: projectID)
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

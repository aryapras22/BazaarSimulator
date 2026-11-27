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
            onDeleteProject: { [weak self] id in self?.deleteProject(id: id) },
            onDeleteAnalysis: { [weak self] id in self?.savedDashboardViewModels[id] = nil }
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
            onSimulate: { [weak router] layout, layouts in
                router?.showSimulation(projectID: projectID, layout: layout, analysisID: analysisID, layouts: layouts)
            },
            onOpenParameters: { [weak router] in
                router?.showParameters(projectID: projectID, analysisID: analysisID)
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
        let created = DashboardViewModel(
            projectID: projectID,
            session: session,
            analysisService: services.analysisService,
            catalog: services.presetCatalog,
            onBack: { [weak router] in
                router?.showSetup(projectID: projectID)
            },
            onSimulate: { [weak router] layout, _ in
                router?.showSimulation(projectID: projectID, layout: layout)
            },
            onOpenParameters: { [weak router] in
                router?.showParameters(projectID: projectID)
            }
        )
        dashboardViewModels[projectID] = created
        return created
    }

    func makeSimulationPlayerViewModel(
        projectID: UUID,
        layout: LayoutID,
        analysisID: UUID? = nil
    ) -> SimulationPlayerViewModel {
        SimulationPlayerViewModel(
            projectID: projectID,
            layoutID: layout,
            analysisID: analysisID,
            layoutIDs: router.simulationLayoutIDs,
            session: services.projectSession,
            analysisService: services.analysisService,
            catalog: services.presetCatalog,
            onBack: { [weak router] in
                router?.closeSimulation(projectID: projectID, analysisID: analysisID)
            }
        )
    }

    func makeParametersViewModel(
        projectID: UUID,
        analysisID: UUID? = nil,
        onClose: @escaping () -> Void,
        onApply: (() -> Void)? = nil
    ) -> ParametersViewModel {
        let initial = analysisID.flatMap {
            services.projectSession.savedAnalysis(id: $0, in: projectID)?.parameters
        }
        return ParametersViewModel(
            projectID: projectID,
            session: services.projectSession,
            catalog: services.presetCatalog,
            initialParameters: initial,
            onClose: onClose,
            onApply: onApply
        )
    }
}

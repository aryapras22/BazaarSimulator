import SwiftUI

struct RootView: View {
    private let services: AppServices
    @State private var router: AppRouter
    @State private var factory: ProjectScreenFactory
    @State private var libraryViewModel: ProjectLibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(services: AppServices? = nil) {
        let effectiveServices = services ?? AppServices()
        let initialDestination = effectiveServices.initialDestination
        let router = AppRouter(destination: initialDestination)
        let factory = ProjectScreenFactory(services: effectiveServices, router: router)
        self.services = effectiveServices
        _router = State(initialValue: router)
        _factory = State(initialValue: factory)
        _libraryViewModel = State(initialValue: factory.makeLibraryViewModel())
        switch initialDestination {
        case .editor, .simulation:
            _columnVisibility = State(initialValue: .detailOnly)
        default:
            _columnVisibility = State(initialValue: .all)
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProjectLibraryView(viewModel: libraryViewModel)
        } detail: {
            detailView
        }
        .appBackground()
        .preferredColorScheme(.dark)
        .onChange(of: router.destination) { _, newDestination in
            switch newDestination {
            case .editor, .simulation:
                columnVisibility = .detailOnly
            default:
                columnVisibility = .all
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.destination {
        case .empty:
            EmptyWorkspaceView()
        case .setup(let projectID):
            ProjectSetupView(viewModel: factory.makeSetupViewModel(projectID: projectID))
                .id(projectID)
        case .analysis(let projectID), .review(let projectID):
            AnalysisView(
                projectID: projectID,
                session: services.projectSession,
                onOpenEditor: { router.showEditor(projectID: projectID) },
                onOpenSimulation: { router.showSimulation(projectID: projectID) },
                onBackToSetup: { router.showSetup(projectID: projectID) }
            )
            .id(projectID)
        case .editor(let projectID):
            LayoutEditorView(viewModel: factory.makeLayoutEditorViewModel(projectID: projectID))
                .id(projectID)
        case .simulation(let projectID):
            SimulationView(
                viewModel: factory.makeSimulationViewModel(projectID: projectID),
                onDismiss: { router.showAnalysis(projectID: projectID) }
            )
            .id(projectID)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

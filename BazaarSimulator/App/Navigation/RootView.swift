import SwiftUI

struct RootView: View {
    private let services: AppServices
    @State private var router: AppRouter
    @State private var factory: ProjectScreenFactory
    @State private var libraryViewModel: ProjectLibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(services: AppServices? = nil) {
        let effectiveServices = services ?? AppServices()
        let initialDestination: AppDestination
        if let activeID = effectiveServices.projectSession.activeProjectID {
            if effectiveServices.projectSession.draft(for: activeID) != nil {
                initialDestination = .review(projectID: activeID)
            } else {
                initialDestination = .setup(projectID: activeID)
            }
        } else {
            initialDestination = .empty
        }
        let router = AppRouter(destination: initialDestination)
        let factory = ProjectScreenFactory(services: effectiveServices, router: router)
        self.services = effectiveServices
        _router = State(initialValue: router)
        _factory = State(initialValue: factory)
        _libraryViewModel = State(initialValue: factory.makeLibraryViewModel())
        if case .review = initialDestination {
            _columnVisibility = State(initialValue: .detailOnly)
        } else {
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
            if case .review = newDestination {
                columnVisibility = .detailOnly
            } else {
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
        case .review(let projectID):
            LayoutEditorView(viewModel: factory.makeLayoutEditorViewModel(projectID: projectID))
                .id(projectID)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

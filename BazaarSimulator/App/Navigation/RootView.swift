import SwiftUI

struct RootView: View {
    private let services: AppServices
    @State private var router: AppRouter
    @State private var factory: ProjectScreenFactory
    @State private var libraryViewModel: ProjectLibraryViewModel

    init(services: AppServices? = nil) {
        let effectiveServices = services ?? AppServices()
        let router = AppRouter()
        let factory = ProjectScreenFactory(services: effectiveServices, router: router)
        self.services = effectiveServices
        _router = State(initialValue: router)
        _factory = State(initialValue: factory)
        _libraryViewModel = State(initialValue: factory.makeLibraryViewModel())
    }

    var body: some View {
        NavigationSplitView {
            ProjectLibraryView(viewModel: libraryViewModel)
        } detail: {
            detailView
        }
        .appBackground()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.destination {
        case .empty:
            EmptyWorkspaceView()
        case .setup(let projectID):
            ProjectSetupView(viewModel: factory.makeSetupViewModel(projectID: projectID))
                .id(projectID)
        case .review:
            ReviewPlaceholderView()
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

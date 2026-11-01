import SwiftUI

struct RootView: View {
    let services: AppServices
    @State private var router = AppRouter()
    @State private var libraryViewModel: ProjectLibraryViewModel?

    init(services: AppServices? = nil) {
        self.services = services ?? AppServices()
    }

    var body: some View {
        NavigationSplitView {
            if let libraryViewModel {
                ProjectLibraryView(viewModel: libraryViewModel)
            }
        } detail: {
            detailView
        }
        .appBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            if libraryViewModel == nil {
                libraryViewModel = ProjectLibraryViewModel(
                    session: services.projectSession,
                    router: router
                )
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.destination {
        case .empty:
            EmptyWorkspaceView()
        case .setup:
            let projectID = services.projectSession.activeProjectID ?? UUID()
            ProjectSetupView(
                viewModel: ProjectSetupViewModel(
                    projectID: projectID,
                    session: services.projectSession,
                    importQueue: services.importQueue,
                    router: router
                )
            )
        case .reviewPlaceholder:
            ReviewPlaceholderView()
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

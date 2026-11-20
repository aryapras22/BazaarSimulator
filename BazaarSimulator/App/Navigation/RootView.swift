import SwiftUI

struct RootView: View {
    private let services: AppServices
    @State private var router: AppRouter
    @State private var factory: ProjectScreenFactory
    @State private var libraryViewModel: ProjectLibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openWindow) private var openWindow
    @State private var isFullScreen = false

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
        case .editor:
            _columnVisibility = State(initialValue: .detailOnly)
        default:
            _columnVisibility = State(initialValue: .all)
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProjectLibraryView(viewModel: libraryViewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 260)
                // The strip over the sidebar has no bar of its own, in a window or in full screen, so the sidebar's own
                // color runs up to the top edge. Over the page, full screen shows the page's color, set below.
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        } detail: {
            detailView
                .toolbarBackground(Palette.background, for: .windowToolbar)
                .toolbarBackgroundVisibility(isFullScreen ? .visible : .hidden, for: .windowToolbar)
        }
        // The Analysis page is laid out for this much room, so the window cannot be dragged smaller.
        .frame(minWidth: 1280, minHeight: 800)
        .appDialog(deletionDialog)
        .appBackground()
        .preferredColorScheme(.dark)
        // In full screen the toolbar, and the sidebar button in it, stays showing like in a window. The window's own
        // buttons appear only when the pointer goes to the top left, as in Notes.
        .windowToolbarFullScreenVisibility(.automatic)
        // In full screen the page always starts below the toolbar, so nothing collides with it. In a window the page runs
        // up under the transparent toolbar.
        .environment(\.pageClearsToolbar, isFullScreen)
        .onAppear {
            isFullScreen = NSApp.keyWindow?.styleMask.contains(.fullScreen) ?? false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .sheet(item: parametersRequest) { request in
            ParametersSheet {
                factory.makeParametersViewModel(
                    projectID: request.projectID,
                    onClose: { router.dismissParameters() },
                    onApply: { router.showAnalysis(projectID: request.projectID) }
                )
            }
            .presentationBackground(.clear)
        }
        .onChange(of: router.simulationRequest) { _, request in
            guard let request else { return }
            openWindow(id: SimulationWindowContent.windowID, value: request)
            router.clearSimulationRequest()
        }
        .onChange(of: router.destination) { _, newDestination in
            switch newDestination {
            case .editor:
                columnVisibility = .detailOnly
            default:
                columnVisibility = .all
            }
        }
    }

    /// The question over the whole window when a project or an analysis was asked to be deleted from the sidebar.
    private var deletionDialog: Binding<AppDialogContent?> {
        Binding(
            get: {
                libraryViewModel.pendingDeletion.map { pending in
                    AppDialogContent(
                        title: pending.title,
                        message: Text(pending.message),
                        kind: .confirm(confirmTitle: "Delete", action: { libraryViewModel.confirmDeletion() })
                    )
                }
            },
            set: { if $0 == nil { libraryViewModel.cancelDeletion() } }
        )
    }

    private var parametersRequest: Binding<ParametersRequest?> {
        Binding(
            get: { router.parametersProjectID.map(ParametersRequest.init) },
            set: { if $0 == nil { router.dismissParameters() } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.destination {
        case .empty:
            EmptyWorkspaceView(
                hasProjects: !services.projectSession.projects.isEmpty,
                onAddProject: { libraryViewModel.createProject() }
            )
        case .setup(let projectID):
            ProjectSetupView(viewModel: factory.makeSetupViewModel(projectID: projectID))
                .id(projectID)
        case .analysis(let projectID), .review(let projectID):
            DashboardView(viewModel: factory.makeDashboardViewModel(projectID: projectID)) { close in
                ParametersView(viewModel: factory.makeParametersViewModel(projectID: projectID, onClose: close))
            }
            .id(projectID)
        case .savedAnalysis(let projectID, let analysisID):
            DashboardView(
                viewModel: factory.makeSavedDashboardViewModel(projectID: projectID, analysisID: analysisID)
            ) { close in
                ParametersView(
                    viewModel: factory.makeParametersViewModel(
                        projectID: projectID,
                        analysisID: analysisID, //only diff from dev btw
                        onClose: close,
                        onApply: { router.showAnalysis(projectID: projectID) }
                    )
                )
            }
            .id(analysisID)
        case .editor(let projectID):
            LayoutEditorView(viewModel: factory.makeLayoutEditorViewModel(projectID: projectID))
                .id(projectID)
        }
    }
}

private struct ParametersRequest: Identifiable {
    let projectID: UUID
    var id: UUID { projectID }
}

/// Builds the Parameters view model once per presentation, so a redraw of the app does not reset it.
private struct ParametersSheet: View {
    @State private var viewModel: ParametersViewModel

    init(make: () -> ParametersViewModel) {
        _viewModel = State(initialValue: make())
    }

    var body: some View {
        ParametersView(viewModel: viewModel)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

import SwiftUI

struct RootView: View {
    private let services: AppServices
    @State private var router: AppRouter
    @State private var factory: ProjectScreenFactory
    @State private var libraryViewModel: ProjectLibraryViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
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
        case .editor, .simulation:
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
        // Insights and Parameters cover the whole window, so the window is blurred behind them, the sidebar too.
        .blur(radius: isCoveredByModal ? 14 : 0)
        .appDialog(deletionDialog)
        .appBackground()
        .overlay {
            if let analysisViewModel {
                InsightsOverlay(viewModel: analysisViewModel)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isCoveredByModal)
        .preferredColorScheme(.dark)
        // In full screen the toolbar, and the sidebar button in it, stays showing like in a window. The window's own
        // buttons appear only when the pointer goes to the top left, as in Notes.
        .windowToolbarFullScreenVisibility(.automatic)
        // In full screen the page always starts below the toolbar, so nothing collides with it. In a window the page runs
        // up under the transparent toolbar.
        .environment(\.pageClearsToolbar, isFullScreen)
        .onAppear {
            // A window restored in full screen is not key yet when this runs, so any full screen window counts.
            isFullScreen = NSApp.windows.contains { $0.styleMask.contains(.fullScreen) }
            NSApp.windows.filter { $0.styleMask.contains(.titled) }.forEach(Self.paintTitlebar)
            // The bar's window is built after the page appears when the app opens in full screen.
            DispatchQueue.main.async(execute: Self.paintSidebarStrip)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { note in
            isFullScreen = true
            (note.object as? NSWindow).map(Self.paintTitlebar)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            Self.paintSidebarStrip()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
        .overlay {
            if let request = parametersRequest {
                GlassModal(maxWidth: 860, onOutsideTap: { router.dismissParameters() }) { width in
                    ParametersSheet(width: width, showsBackground: false) {
                        factory.makeParametersViewModel(
                            projectID: request.projectID,
                            analysisID: request.analysisID,
                            onClose: { router.dismissParameters() },
                            onApply: {
                                router.showAnalysis(projectID: request.projectID)
                                factory.makeDashboardViewModel(projectID: request.projectID).startSimulation()
                            }
                        )
                    }
                    .id(request.id)
                    .onExitCommand { router.dismissParameters() }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: parametersRequest)
        .onChange(of: router.destination) { _, newDestination in
            switch newDestination {
            case .editor, .simulation:
                columnVisibility = .detailOnly
            default:
                columnVisibility = .all
            }
        }
    }

    /// In full screen AppKit covers the toolbar with an opaque title bar fill in the window's background color, over
    /// any SwiftUI toolbar background, so the window itself takes the page's color.
    private static func paintTitlebar(_ window: NSWindow) {
        window.backgroundColor = NSColor(Palette.background)
    }

    private static let sidebarStripID = NSUserInterfaceItemIdentifier("sidebarStrip")

    /// That fill takes one color for the whole bar, so the part over the sidebar gets a view of the sidebar's color laid
    /// into it. The fill is a private AppKit view; if a macOS update renames it, nothing is found and the bar stays navy.
    private static func paintSidebarStrip() {
        for window in NSApp.windows {
            guard let bar = window.contentView?.superview else { continue }
            func fills(in view: NSView) -> [NSView] {
                let isSidebarFill = String(describing: type(of: view)) == "NSTitlebarBackgroundView"
                    && view.frame.minX == 0 && view.frame.width < bar.frame.width
                return (isSidebarFill ? [view] : []) + view.subviews.flatMap(fills)
            }
            fills(in: bar).forEach(addStrip)
        }
    }

    private static func addStrip(to fill: NSView) {
        if !fill.subviews.contains(where: { $0.identifier == sidebarStripID }) {
            let strip = NSView(frame: fill.bounds)
            strip.identifier = sidebarStripID
            strip.wantsLayer = true
            strip.layer?.backgroundColor = NSColor(Palette.sidebarBase).cgColor
            strip.autoresizingMask = [.width, .height]
            // On top of the fill's own scroll edge and glass layers, which paint navy over anything below them. The
            // sidebar button sits in the toolbar view above the whole fill, so the strip does not cover it.
            fill.addSubview(strip, positioned: .above, relativeTo: nil)
        }
    }

    /// The page on screen, when it is an analysis. Its Insights are drawn over the whole window from here.
    private var analysisViewModel: DashboardViewModel? {
        switch router.destination {
        case .analysis(let projectID), .review(let projectID):
            factory.makeDashboardViewModel(projectID: projectID)
        case .savedAnalysis(let projectID, let analysisID):
            factory.makeSavedDashboardViewModel(projectID: projectID, analysisID: analysisID)
        default:
            nil
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

    private var isCoveredByModal: Bool {
        analysisViewModel?.isInsightsPresented == true || parametersRequest != nil
    }

    private var parametersRequest: ParametersRequest? {
        router.parametersProjectID.map {
            ParametersRequest(projectID: $0, analysisID: router.parametersAnalysisID)
        }
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
                ParametersView(
                    viewModel: factory.makeParametersViewModel(projectID: projectID, onClose: close),
                    showsBackground: false
                )
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
                    ),
                    showsBackground: false
                )
            }
            .id(analysisID)
        case .editor(let projectID):
            LayoutEditorView(viewModel: factory.makeLayoutEditorViewModel(projectID: projectID))
                .id(projectID)
        case .simulation(let projectID, let layout, let analysisID):
            SimulationPlayerView(
                viewModel: factory.makeSimulationPlayerViewModel(
                    projectID: projectID, layout: layout, analysisID: analysisID
                )
            )
            .id(
                "\(projectID.uuidString)-\(layout.rawValue)-\(analysisID?.uuidString ?? "latest")-"
                    + (router.simulationLayoutIDs?.map(\.uuidString).joined() ?? "")
            )
        }
    }
}

private struct ParametersRequest: Identifiable, Equatable {
    let projectID: UUID
    let analysisID: UUID?
    var id: String { "\(projectID.uuidString)-\(analysisID?.uuidString ?? "latest")" }
}

/// Builds the Parameters view model once per presentation, so a redraw of the app does not reset it.
private struct ParametersSheet: View {
    @State private var viewModel: ParametersViewModel
    private let width: CGFloat
    private let showsBackground: Bool

    init(width: CGFloat = 860, showsBackground: Bool = true, make: () -> ParametersViewModel) {
        self.width = width
        self.showsBackground = showsBackground
        _viewModel = State(initialValue: make())
    }

    var body: some View {
        ParametersView(viewModel: viewModel, width: width, showsBackground: showsBackground)
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

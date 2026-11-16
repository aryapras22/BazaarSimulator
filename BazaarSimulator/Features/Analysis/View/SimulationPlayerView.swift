import SwiftUI

/// The simulator: the busiest window of one layout, played over its floor plan.
struct SimulationPlayerView: View {
    @Bindable var viewModel: SimulationPlayerViewModel

    @State private var clock = PlaybackClock(duration: SimulationPlayerViewModel.playbackSeconds)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch viewModel.phase {
            case .ready: player
            case .loading: notice("Running the simulation…", showsProgress: true)
            case .needsLayouts: notice("Add a floor plan to see the simulation.", showsProgress: false)
            }
        }
        // Room for the window's top controls, the same in a window and in full screen where they are hidden.
        .padding(.top, 28)
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.backgroundMain.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    private var player: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !clock.isRunning)) { context in
            let time = clock.time(at: context.date)

            GeometryReader { geometry in
                let frame = PlayerFrame(size: geometry.size, planAspect: viewModel.planAspect)

                ZStack(alignment: .topLeading) {
                    switch viewModel.viewStyle {
                    case .twoD:
                        SimulationPlanView(viewModel: viewModel, time: time)
                            .frame(width: frame.stage.width, height: frame.stage.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .position(x: frame.stage.midX, y: frame.stage.midY)
                    case .threeD:
                        scene(at: time)
                            .frame(width: frame.stage.width, height: frame.stage.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .position(x: frame.stage.midX, y: frame.stage.midY)
                    }

                    SimulationInfoPanel(
                        layoutName: viewModel.layoutID.name,
                        visitorsInside: viewModel.visitorsInside(at: time),
                        mode: viewModel.mode,
                        visitorTypes: viewModel.visitorTypes
                    )
                    .padding(.leading, PlayerFrame.panelOrigin.x)
                    .padding(.top, PlayerFrame.panelOrigin.y)

                    SegmentedTabBar(
                        options: SimulationMode.allCases,
                        selection: $viewModel.mode,
                        title: \.title,
                        style: .simulation
                    )
                    .accessibilityLabel("Simulation overlay")
                    .frame(width: frame.tabs.width, height: frame.tabs.height)
                    .position(x: frame.tabs.midX, y: frame.tabs.midY)

                    SegmentedTabBar(
                        options: SimulationViewStyle.allCases,
                        selection: $viewModel.viewStyle,
                        title: \.title,
                        style: .simulation
                    )
                    .accessibilityLabel("View style")
                    .frame(width: frame.styleSwitch.width, height: frame.styleSwitch.height)
                    .position(x: frame.styleSwitch.midX, y: frame.styleSwitch.midY)

                    Text(viewModel.mode.summary(windowText: viewModel.windowText))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: frame.tabs.width)
                        .position(x: frame.tabs.midX, y: PlayerFrame.summaryCenterY)
                        .id(viewModel.mode)
                        .transition(.opacity)

                    PlaybackBar(
                        clock: $clock,
                        time: time,
                        eventDurationSeconds: viewModel.replay?.durationSeconds ?? 39_600
                    )
                        .frame(width: frame.bar.width, height: frame.bar.height)
                        .position(x: frame.bar.midX, y: frame.bar.midY)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.mode)
            }
        }
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            DashboardBackground(spacing: 64, fill: Color(hex: 0x142741), line: Color(hex: 0x1A2F4C), lineWidth: 2)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color(hex: 0x34465F), lineWidth: 1) }
        }
        .padding(.top, 17)
        .padding(.leading, 17)
        .padding(.trailing, 19)
        .padding(.bottom, 23)
        .onAppear { if !reduceMotion { clock.play() } }
    }

    @ViewBuilder
    private func scene(at time: Double) -> some View {
        if let venue = viewModel.venue() {
            Metal3DSceneView(venue: venue, frame: viewModel.sceneFrame(at: time))
                .accessibilityLabel("\(viewModel.layoutID.name) in 3D")
        }
    }

    private func notice(_ text: String, showsProgress: Bool) -> some View {
        VStack(spacing: 14) {
            if showsProgress { ProgressView() }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct PlayerFrame {
    static let panelOrigin = CGPoint(x: 23.5, y: 19.5)
    static let panelWidth = SimulationInfoPanel.width
    static let summaryCenterY: CGFloat = 79

    static let styleSwitchWidth: CGFloat = 132

    let plan: CGRect
    /// The 3D scene: everything to the right of the panel, above the playback bar.
    let stage: CGRect
    let tabs: CGRect
    let styleSwitch: CGRect
    let bar: CGRect

    init(size: CGSize, planAspect: CGFloat) {
        let mid = size.width / 2
        let panelRight = Self.panelOrigin.x + Self.panelWidth

        let planHeight = max(min(788.5, size.height - 150.5), 240)
        let stageLeft = panelRight + 16
        let stageWidth = max(size.width - stageLeft - 20, 240)
        stage = CGRect(x: stageLeft, y: 103, width: stageWidth, height: planHeight)

        let fittedWidth = min(planHeight * planAspect, stageWidth)
        let fittedHeight = fittedWidth / max(planAspect, 0.01)
        let planCenter = stage.midX
        plan = CGRect(x: planCenter - fittedWidth / 2, y: 103 + (planHeight - fittedHeight) / 2, width: fittedWidth, height: fittedHeight)

        styleSwitch = CGRect(x: size.width - 20 - Self.styleSwitchWidth, y: 16, width: Self.styleSwitchWidth, height: 44.5)
        let tabCenter = mid + 69.5
        let tabRoom = min(2 * (tabCenter - panelRight - 24), 2 * (styleSwitch.minX - 16 - tabCenter))
        let tabWidth = max(min(919, tabRoom), 360)
        tabs = CGRect(x: tabCenter - tabWidth / 2, y: 16, width: tabWidth, height: 44.5)

        bar = CGRect(
            x: mid - 9.5 - PlaybackBar.width / 2,
            y: size.height - 47.5 - PlaybackBar.height,
            width: PlaybackBar.width,
            height: PlaybackBar.height
        )
    }
}

extension SegmentedTabBarStyle {
    static let simulation = SegmentedTabBarStyle(
        height: 44.5,
        trackRadius: 8,
        pillRadius: 7,
        pillInset: 3,
        track: Color(hex: 0x243E5D),
        trackBorder: Color(hex: 0x3C5372),
        pill: AnyShapeStyle(LinearGradient(
            colors: [Color(hex: 0x5C708B), Color(hex: 0x506583)], startPoint: .top, endPoint: .bottom
        )),
        pillBorder: Color(hex: 0x7486A0).opacity(0.7),
        unselectedWeight: .semibold
    )
}

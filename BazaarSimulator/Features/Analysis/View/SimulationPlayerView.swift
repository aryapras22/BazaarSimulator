import AppKit
import SwiftUI

/// The simulator: the busiest window of one layout, played over its floor plan.
struct SimulationPlayerView: View {
    @Bindable var viewModel: SimulationPlayerViewModel

    @State private var clock = PlaybackClock(duration: SimulationPlayerViewModel.playbackSeconds)
    @State private var keyMonitor: Any?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pageClearsToolbar) private var pageClearsToolbar

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch viewModel.phase {
            case .ready:
                player
            case .loading:
                notice("Running the simulation…", showsProgress: true)
            case .needsLayouts:
                notice("Add a floor plan to see the simulation.", showsProgress: false)
            }

            if viewModel.phase != .ready {
                backButton
                    .padding(.leading, pageClearsToolbar ? Spacing.l : 150)
                    .padding(.top, Spacing.m)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .underToolbarInWindow()
        .background(Color.backgroundMain.ignoresSafeArea())
        .task { await viewModel.load() }
        .onAppear { installSpaceMonitor() }
        .onDisappear { removeSpaceMonitor() }
    }

    private func installSpaceMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isPlainSpace = event.keyCode == 49
                && !event.isARepeat
                && event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            guard isPlainSpace, viewModel.phase == .ready,
                  !(event.window?.firstResponder is NSText) else {
                return event
            }
            clock.toggle()
            return nil
        }
    }

    private func removeSpaceMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private var player: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !clock.isRunning)) { context in
            let time = clock.time(at: context.date)
            let topInset: CGFloat = pageClearsToolbar ? Spacing.m : 44

            stage(at: time)
                .ignoresSafeArea()
                .overlay(alignment: .top) { topOverlay(topInset: topInset) }
                .overlay(alignment: .topLeading) {
                    GlassEffectContainer(spacing: Spacing.m) {
                        VStack(alignment: .leading, spacing: Spacing.m) {
                            SimulationInfoPanel(
                                layoutName: viewModel.layoutID.name,
                                visitorsInside: viewModel.visitorsInside(at: time),
                                mode: viewModel.mode,
                                visitorTypes: viewModel.visitorTypes
                            )

                            if !viewModel.tenantTypes.isEmpty {
                                SimulationTenantLegendPanel(tenantTypes: viewModel.tenantTypes)
                            }
                        }
                    }
                    .padding(.leading, Spacing.l)
                    .padding(.top, topInset + 58)
                }
                .overlay(alignment: .bottom) {
                    PlaybackBar(
                        clock: $clock,
                        time: time,
                        eventDurationSeconds: viewModel.replay?.durationSeconds ?? 39_600
                    )
                    .padding(.bottom, Spacing.l)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: viewModel.mode)
        }
    }

    @ViewBuilder
    private func stage(at time: Double) -> some View {
        switch viewModel.viewStyle {
        case .twoD:
            SimulationPlanView(viewModel: viewModel, time: time)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .threeD:
            scene(at: time)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func topOverlay(topInset: CGFloat) -> some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                HStack(spacing: Spacing.m) {
                    backButton
                    Spacer(minLength: Spacing.m)
                    SegmentedTabBar(
                        options: SimulationViewStyle.allCases,
                        selection: $viewModel.viewStyle,
                        title: \.title,
                        style: .simulation
                    )
                    .accessibilityLabel("View style")
                    .frame(width: 132, height: 44.5)
                }

                SegmentedTabBar(
                    options: SimulationMode.allCases,
                    selection: $viewModel.mode,
                    title: \.title,
                    style: .simulation
                )
                .accessibilityLabel("Simulation overlay")
                .frame(maxWidth: 540)
                .frame(height: 44.5)
                .padding(.horizontal, 160)
            }

            Text(viewModel.mode.summary(windowText: viewModel.windowText))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.textPrimary.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: Capsule())
                .id(viewModel.mode)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, topInset)
    }

    private var backButton: some View {
        Button(action: viewModel.onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.textPrimary)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(Color.backButtonFill)
                        .overlay { Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.75) }
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Back")
        .accessibilityLabel("Back")
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

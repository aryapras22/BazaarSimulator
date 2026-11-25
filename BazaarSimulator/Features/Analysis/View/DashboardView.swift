import SwiftUI

/// What the controls in the window's top bar measure.
private enum TopBar {
    /// The height of Back and Parameters, the same as the sidebar toggle.
    static let controlHeight: CGFloat = 36
    /// How far Back and Parameters sit from the edges of the bar, the same on both sides.
    static let edgeInset: CGFloat = 12
    /// The room between Back and the title.
    static let titleGap: CGFloat = 14
}

/// The compare page. The Parameters screen belongs to another feature, so the app passes it in.
struct DashboardView<ParametersSheet: View>: View {
    @Bindable var viewModel: DashboardViewModel
    private let parametersSheet: (_ close: @escaping () -> Void) -> ParametersSheet

    init(
        viewModel: DashboardViewModel,
        @ViewBuilder parametersSheet: @escaping (_ close: @escaping () -> Void) -> ParametersSheet
    ) {
        self.viewModel = viewModel
        self.parametersSheet = parametersSheet
    }

    var body: some View {
        GeometryReader { geometry in
            DashboardContent(
                viewModel: viewModel,
                metrics: DashboardMetrics(size: geometry.size, layoutCount: max(viewModel.layoutIDs.count, 1))
            )
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        // Back, the title and Parameters are in the window's own top bar, level with the traffic lights and the sidebar
        // toggle in a window and in full screen, and clear of them when the sidebar is collapsed.
        .toolbar {
            // Back and Parameters are drawn here, not by the system, so they are the same height and equally round,
            // and sit as far from the window's edges as each other. The window's own look would make one taller
            // than the other and leave Back touching the edge.
            ToolbarItem(placement: .navigation) {
                Button(action: viewModel.onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.textPrimary)
                        .frame(width: TopBar.controlHeight, height: TopBar.controlHeight)
                        .background {
                            Circle()
                                .fill(Color.backButtonFill)
                                .overlay { Circle().strokeBorder(.white.opacity(0.14), lineWidth: 0.75) }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, TopBar.edgeInset)
                .help("Back")
                .accessibilityLabel("Back")
            }
            .sharedBackgroundVisibility(.hidden)
            // The window shows no title of its own, so the page's name is an item of the bar.
            ToolbarItem(placement: .navigation) {
                Text(viewModel.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, TopBar.titleGap)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible)
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.openParameters() } label: {
                    Text("Parameters")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: TopBar.controlHeight)
                        .background {
                            RoundedRectangle.button
                                .fill(Color.cardButtonFill)
                                .overlay {
                                    RoundedRectangle.button
                                        .strokeBorder(Color.controlBorder.opacity(0.55), lineWidth: 0.75)
                                }
                        }
                        .contentShape(RoundedRectangle.button)
                }
                .buttonStyle(.plain)
                .padding(.trailing, TopBar.edgeInset)
                .help("Change visitors, opening hours and visitor types")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .background { Color.backgroundMain.ignoresSafeArea() }
        .environment(\.layoutNames, viewModel.layoutNames)
        .overlay {
            if viewModel.isParametersPresented {
                GlassModal(maxWidth: 860, onOutsideTap: { viewModel.closeParameters() }) { _ in
                    SheetHost { parametersSheet(viewModel.closeParameters) }
                        .onExitCommand { viewModel.closeParameters() }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.isParametersPresented)
        .task {
            viewModel.startSimulation()
            viewModel.refreshProjectBest()
        }
    }
}

/// Builds the sheet content once per presentation, so a redraw of the page does not reset its state.
private struct SheetHost<Content: View>: View {
    @State private var content: Content

    init(_ make: () -> Content) {
        _content = State(initialValue: make())
    }

    var body: some View {
        content
    }
}

struct DashboardContent: View {
    @Bindable var viewModel: DashboardViewModel
    var metrics: DashboardMetrics = .reference

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewModel.phase {
            case .loading:
                RunningNotice(
                    text: "Running the simulation…",
                    showsProgress: true,
                    progress: viewModel.loadingProgress,
                    previewVenue: viewModel.previewVenue,
                    previewFrame: viewModel.previewFrame,
                    onCancel: { viewModel.cancelSimulation() }
                )
            case .needsLayouts:
                RunningNotice(text: "Add a floor plan to analyse it.", showsProgress: false)
            case .ready:
                comparison
            }
        }
        .padding(.leading, DashboardMetrics.horizontalPadding.leading)
        .padding(.trailing, DashboardMetrics.horizontalPadding.trailing)
        // The page starts below the window's top bar, which holds the back button, the title and Parameters.
        .padding(.top, metrics.headerToCards)
        .padding(.bottom, metrics.bottomPadding)
    }

    @ViewBuilder
    private var comparison: some View {
        let bestPlanID = viewModel.bestChoiceLayoutID
        // The Best Layout summary comes first, then the layouts it chose from.
        if let summary = viewModel.singleSummary {
            SingleLayoutSummaryView(summary: summary, onInsights: { viewModel.isInsightsPresented = true })
        } else if let summary = viewModel.bestLayout {
            BestLayoutSummaryView(summary: summary, onInsights: { viewModel.isInsightsPresented = true })
        }

        // One layout fills the page on its own. Two sit side by side and are compared.
        HStack(alignment: .top, spacing: CardSpacing.gap) {
            ForEach(viewModel.layoutIDs) { layout in
                LayoutComparisonCard(
                    layout: layout,
                    outcome: viewModel.outcome(for: layout),
                    floorPlan: viewModel.floorPlan(for: layout),
                    plan: viewModel.plan(for: layout),
                    peakHourText: viewModel.peakHourText,
                    metrics: metrics,
                    showsSimulate: true,
                    showsWorstSpot: viewModel.isSingleLayout,
                    choices: viewModel.layoutChoices(for: layout),
                    layoutNumber: viewModel.layoutNumber(of:),
                    bestChoiceID: bestPlanID,
                    onChoose: { viewModel.choose($0, for: layout) },
                    onSimulate: { viewModel.simulate(layout) }
                )
            }
        }
        .padding(.top, metrics.cardsToSummary)

        Spacer(minLength: 0)
    }
}

/// Shown instead of the comparison while the simulation runs, or when there is nothing to compare.
private struct RunningNotice: View {
    let text: String
    let showsProgress: Bool
    var progress: Double = 0.0
    var previewVenue: SimulationVenue?
    var previewFrame: SimulationSceneFrame = SimulationSceneFrame()
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            if showsProgress, let previewVenue {
                Metal3DSceneView(
                    venue: previewVenue,
                    frame: previewFrame,
                    backgroundColor: Palette.simulationBackground,
                    initialDistanceScale: 0.72
                )
                    .allowsHitTesting(false)
                    .overlay {
                        Color.backgroundMain.opacity(0.62)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
                    .padding(.vertical, 18)
            }

            let card = VStack(spacing: 12) {
                VStack(spacing: 12) {
                    if showsProgress {
                        ProgressView()
                    }
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.textPrimary)
                    if showsProgress {
                        VStack(spacing: 6) {
                            ProgressView(value: min(max(progress, 0.02), 1.0), total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(Palette.accent)
                                .frame(width: 240)
                            Text("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
                                .font(.system(size: 11.5, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.secondary)
                        .padding(.top, Spacing.xs)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)

            if showsProgress {
                card.glassCardSurface(in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
            } else {
                card
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

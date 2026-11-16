import SwiftUI

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
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background { DashboardBackground().ignoresSafeArea() }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $viewModel.isParametersPresented) {
            SheetHost { parametersSheet(viewModel.closeParameters) }
        }
        .sheet(isPresented: $viewModel.isInsightsPresented) {
            InsightsSheet(viewModel: viewModel)
        }
        .task { viewModel.startSimulation() }
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
            DashboardHeader(
                title: viewModel.title,
                onBack: viewModel.onBack,
                onOpenParameters: viewModel.canEdit ? { viewModel.isParametersPresented = true } : nil
            )

            switch viewModel.phase {
            case .loading:
                RunningNotice(
                    text: "Running the simulation…",
                    showsProgress: true,
                    progress: viewModel.loadingProgress,
                    previewVenue: viewModel.previewVenue,
                    previewFrame: viewModel.previewFrame
                )
            case .needsLayouts:
                RunningNotice(text: "Add a floor plan to analyse it.", showsProgress: false)
            case .ready:
                comparison
            }
        }
        .padding(.leading, DashboardMetrics.horizontalPadding.leading)
        .padding(.trailing, DashboardMetrics.horizontalPadding.trailing)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomPadding)
    }

    @ViewBuilder
    private var comparison: some View {
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
                    showsEdit: viewModel.canEdit,
                    showsWorstSpot: viewModel.isSingleLayout,
                    choices: viewModel.layoutChoices,
                    onChoose: { viewModel.choose($0, for: layout) },
                    onSimulate: { viewModel.onSimulate(layout) },
                    onEdit: { viewModel.onEdit(layout) }
                )
            }
        }
        .padding(.top, metrics.headerToCards)

        if let summary = viewModel.singleSummary {
            SingleLayoutSummaryView(summary: summary, onInsights: { viewModel.isInsightsPresented = true })
                .padding(.top, metrics.cardsToSummary)
        } else if let summary = viewModel.bestLayout {
            BestLayoutSummaryView(summary: summary, onInsights: { viewModel.isInsightsPresented = true })
                .padding(.top, metrics.cardsToSummary)
        }

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

    var body: some View {
        ZStack {
            if showsProgress, let previewVenue {
                Metal3DSceneView(venue: previewVenue, frame: previewFrame)
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
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background {
                if showsProgress && previewVenue != nil {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.backgroundMain.opacity(0.84))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct DashboardHeader: View {
    let title: String
    var onBack: () -> Void = {}
    var onOpenParameters: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
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

            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.textPrimary)
                .padding(.leading, 19)

            Spacer()

            if let onOpenParameters {
                Button("Parameters", action: onOpenParameters)
                    .buttonStyle(ControlButtonStyle())
                    .help("Change visitors, opening hours and visitor types")
            }
        }
        .frame(height: DashboardMetrics.headerHeight)
    }
}

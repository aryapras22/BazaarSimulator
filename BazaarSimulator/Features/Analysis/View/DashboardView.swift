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
                metrics: DashboardMetrics(size: geometry.size)
            )
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background { DashboardBackground().ignoresSafeArea() }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $viewModel.isParametersPresented) {
            SheetHost { parametersSheet(viewModel.closeParameters) }
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
            DashboardHeader(
                title: viewModel.projectName,
                onBack: viewModel.onBack,
                onOpenParameters: { viewModel.isParametersPresented = true }
            )

            HStack(alignment: .top, spacing: CardSpacing.gap) {
                ForEach(LayoutID.allCases) { layout in
                    LayoutComparisonCard(
                        layout: layout,
                        outcome: viewModel.outcome(for: layout),
                        peakHourText: viewModel.simulationResult.peakHourText,
                        metrics: metrics,
                        onSimulate: { viewModel.onSimulate(layout) },
                        onEdit: { viewModel.onEdit(layout) }
                    )
                }
            }
            .padding(.top, metrics.headerToCards)

            AnalysisSection(
                tab: $viewModel.tab,
                content: viewModel.activeContent,
                metrics: metrics
            )
            .padding(.top, metrics.cardsToAnalysis)

            Spacer(minLength: 0)
        }
        .padding(.leading, DashboardMetrics.horizontalPadding.leading)
        .padding(.trailing, DashboardMetrics.horizontalPadding.trailing)
        .padding(.top, metrics.topPadding)
    }
}

struct DashboardHeader: View {
    let title: String
    var onBack: () -> Void = {}
    var onOpenParameters: () -> Void = {}

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

            Button("Parameters", action: onOpenParameters)
                .buttonStyle(ControlButtonStyle(fill: .headerButtonFill, minWidth: 108))

            Button("Legend") {}
                .buttonStyle(ControlButtonStyle(fill: .headerButtonFill, minWidth: 108))
                .padding(.leading, 12)
        }
        .frame(height: DashboardMetrics.headerHeight)
    }
}

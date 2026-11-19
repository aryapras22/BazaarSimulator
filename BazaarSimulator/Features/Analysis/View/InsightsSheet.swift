import SwiftUI

/// The full comparison, opened from the Best Layout summary: one tab for each result, each with the winner and how
/// it changes during the day.
struct InsightsSheet: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.dismiss) private var dismiss

    private var subtitle: String {
        viewModel.isSingleLayout
            ? "Each tab shows how \(LayoutID.one.name) does on one result, then how it changes during the day."
            : "Each tab compares \(LayoutID.one.name) and \(LayoutID.two.name) on one result, then shows how it changes during the day."
    }

    private let metrics = DashboardMetrics(size: CGSize(width: 1197, height: DashboardMetrics.referenceHeight))

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Insights")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(ControlButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }

            if let content = viewModel.activeContent {
                AnalysisSection(tab: $viewModel.tab, content: content, metrics: metrics)
                    .padding(.top, 24)
            }
        }
        .padding(.leading, DashboardMetrics.horizontalPadding.leading)
        .padding(.trailing, DashboardMetrics.horizontalPadding.trailing)
        .padding(.top, 26)
        .padding(.bottom, 28)
        .frame(width: 1197)
        // The same backdrop as the Parameters sheet.
        .background(Palette.background)
        // The islands in the modal are glass too.
        .environment(\.cardsAreGlass, true)
        .preferredColorScheme(.dark)
    }
}

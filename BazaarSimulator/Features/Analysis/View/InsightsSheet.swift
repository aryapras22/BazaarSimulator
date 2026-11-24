import SwiftUI

/// The full comparison, opened from the Best Layout summary: one tab for each result, each with the winner and how
/// it changes during the day.
struct InsightsSheet: View {
    @Bindable var viewModel: DashboardViewModel
    /// How wide the content is laid out. It is the whole reference width unless the window is narrower.
    var width: CGFloat = 1197
    var onClose: () -> Void

    private var subtitle: String {
        let names = viewModel.layoutNames
        return viewModel.isSingleLayout
            ? "Each tab shows how \(names.name(.one)) does on one result, then how it changes during the day."
            : "Each tab compares \(names.name(.one)) and \(names.name(.two)) on one result, "
                + "then shows how it changes during the day."
    }

    private var metrics: DashboardMetrics {
        DashboardMetrics(size: CGSize(width: width, height: DashboardMetrics.referenceHeight))
    }

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
                Button("Close", action: onClose)
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
        .frame(width: width)
        // The islands in the modal are glass too.
        .environment(\.cardsAreGlass, true)
        .preferredColorScheme(.dark)
    }
}

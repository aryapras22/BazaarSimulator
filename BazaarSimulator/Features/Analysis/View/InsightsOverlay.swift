import SwiftUI

/// Insights as a glass card over the whole window, sidebar included. A click outside the card, the Close button or
/// Escape closes it.
struct InsightsOverlay: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        if viewModel.isInsightsPresented {
            GlassModal(maxWidth: 1197, onOutsideTap: { viewModel.isInsightsPresented = false }) { width in
                InsightsSheet(viewModel: viewModel, width: width) { viewModel.isInsightsPresented = false }
            }
        }
    }
}

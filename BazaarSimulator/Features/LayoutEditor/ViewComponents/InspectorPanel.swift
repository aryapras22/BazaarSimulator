import SwiftUI

enum InspectorPanelMetrics {
    /// Fixed width of the inspector column, in points.
    static let width: CGFloat = 320
}

struct InspectorPanel<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(title)
                .font(Typography.panelTitle)
                .foregroundStyle(Palette.textPrimary)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    content()
                }
            }

            Spacer(minLength: 0)

            footer()
        }
        .padding(Spacing.l)
        .frame(width: InspectorPanelMetrics.width)
        .frame(maxHeight: .infinity)
        .background(Palette.surface)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(width: 1)
        }
    }
}

#Preview {
    InspectorPanel(title: "Preview Panel") {
        Text("Panel content")
            .foregroundStyle(Palette.textSecondary)
    } footer: {
        EmptyView()
    }
    .frame(height: 400)
    .preferredColorScheme(.dark)
}

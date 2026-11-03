import SwiftUI

enum InspectorPanelMetrics {
    /// Fixed width of the floating inspector panel, in points.
    static let width: CGFloat = 340
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
        .padding(Spacing.xl)
        .frame(width: InspectorPanelMetrics.width)
        .background(
            RoundedRectangle(cornerRadius: Radius.xl)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.xl)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }
}

struct InspectorSaveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body)
            .foregroundStyle(isEnabled ? Color.white : Palette.primaryDisabledOnSurfaceText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(
                        isEnabled
                            ? Palette.accent.opacity(configuration.isPressed ? 0.85 : 1.0)
                            : Palette.primaryDisabledOnSurface
                    )
            )
    }
}

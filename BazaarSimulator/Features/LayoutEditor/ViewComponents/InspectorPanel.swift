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

#Preview {
    InspectorPanel(title: "Preview Panel") {
        Text("Panel content")
            .foregroundStyle(Palette.textSecondary)
    } footer: {
        Button("Save Changes") {}
            .buttonStyle(InspectorSaveButtonStyle())
    }
    .frame(height: 400)
    .preferredColorScheme(.dark)
}

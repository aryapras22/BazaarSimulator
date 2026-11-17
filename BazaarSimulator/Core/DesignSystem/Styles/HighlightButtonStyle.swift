import SwiftUI

/// The orange button for the one action a screen leads to, such as Set Parameters or Add Project. It dims to the
/// dark red of the disabled primary button while the action is not available.
struct HighlightButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isEnabled ? Color(hex: 0x1A0F08) : Palette.primaryDisabledText)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(
                isEnabled
                    ? Palette.highlight.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : Palette.primaryDisabled
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
    }
}

extension ButtonStyle where Self == HighlightButtonStyle {
    static var highlight: HighlightButtonStyle { HighlightButtonStyle() }
}

#Preview("Enabled and disabled") {
    VStack(spacing: Spacing.m) {
        Button("Set Parameters") {}.buttonStyle(.highlight)
        Button("Set Parameters") {}.buttonStyle(.highlight).disabled(true)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

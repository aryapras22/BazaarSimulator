import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body)
            .foregroundColor(isEnabled ? .white : Palette.primaryDisabledText)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .background(
                isEnabled
                    ? Palette.accent.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : Palette.primaryDisabled
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

#Preview("Normal") {
    Button("Continue") {}
        .buttonStyle(.primary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Button("Continue to Layout Review and Parameter Setup") {}
        .buttonStyle(.primary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Button("") {}
        .buttonStyle(.primary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Button("Continue") {}
        .buttonStyle(.primary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Button("Continue") {}
        .buttonStyle(.primary)
        .disabled(true)
        .padding()
        .preferredColorScheme(.dark)
}

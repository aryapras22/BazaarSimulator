import SwiftUI

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.body)
            .foregroundColor(isEnabled ? Palette.textPrimary : Palette.textDisabled)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(
                isEnabled
                    ? Palette.control.opacity(configuration.isPressed ? 0.8 : 1.0)
                    : Palette.controlDisabled
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

#Preview("Normal") {
    Button("Choose files...") {}
        .buttonStyle(.secondary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Button("Choose layout PDF files from disk...") {}
        .buttonStyle(.secondary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Button("") {}
        .buttonStyle(.secondary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Button("Cancel") {}
        .buttonStyle(.secondary)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Button("Choose files...") {}
        .buttonStyle(.secondary)
        .disabled(true)
        .padding()
        .preferredColorScheme(.dark)
}

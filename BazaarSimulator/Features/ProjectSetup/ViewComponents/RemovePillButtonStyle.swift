import SwiftUI

struct RemovePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.caption)
            .foregroundColor(Palette.destructive)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Palette.controlOnSurface.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(Palette.controlOnSurfaceBorder, lineWidth: 1)
            )
    }
}

extension ButtonStyle where Self == RemovePillButtonStyle {
    static var removePill: RemovePillButtonStyle { RemovePillButtonStyle() }
}

#Preview {
    Button("Remove") {}
        .buttonStyle(.removePill)
        .padding()
        .preferredColorScheme(.dark)
}

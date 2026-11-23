import SwiftUI

private struct GlassModalSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        content
            // A frosted layer under the glass, so what shows through the card is blurred more.
            .background(.regularMaterial, in: shape)
            .glassEffect(.regular, in: shape)
    }
}

extension View {
    /// The background every card that floats over the window shares: frosted glass with rounded corners. Insights,
    /// Parameters, the layout preview and the dialogs all use it.
    func glassModalSurface() -> some View {
        modifier(GlassModalSurface())
    }
}

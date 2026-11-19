import SwiftUI

private struct GlassPopover: ViewModifier {
    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .presentationBackground(.clear)
    }
}

extension View {
    /// The look of the small info cards: glass instead of the popover's solid background.
    func glassPopover() -> some View {
        modifier(GlassPopover())
    }
}

import SwiftUI

extension View {
    /// The background every card that floats over the window shares: frosted glass with rounded corners. Insights,
    /// Parameters, the layout preview and the dialogs all use it. It is `glassCardSurface` with the modal radius.
    func glassModalSurface() -> some View {
        glassCardSurface(in: RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
    }
}

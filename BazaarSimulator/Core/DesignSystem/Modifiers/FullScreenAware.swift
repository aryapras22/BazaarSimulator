import SwiftUI

private struct PageClearsToolbarKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the page has to start below the toolbar. The root view sets it.
    var pageClearsToolbar: Bool {
        get { self[PageClearsToolbarKey.self] }
        set { self[PageClearsToolbarKey.self] = newValue }
    }
}

private struct UnderToolbarInWindow: ViewModifier {
    @Environment(\.pageClearsToolbar) private var pageClearsToolbar

    func body(content: Content) -> some View {
        // The page runs up under the toolbar unless something in the toolbar would sit over it.
        content.ignoresSafeArea(.container, edges: pageClearsToolbar ? [] : .top)
    }
}

extension View {
    func underToolbarInWindow() -> some View {
        modifier(UnderToolbarInWindow())
    }
}

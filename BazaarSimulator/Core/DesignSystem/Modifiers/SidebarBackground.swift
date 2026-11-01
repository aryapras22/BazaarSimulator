import SwiftUI

struct SidebarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Palette.sidebarBase
                    RadialGradient(
                        colors: [Palette.glowBlue.opacity(0.85), Color.clear],
                        center: .init(x: 0.1, y: 0.8),
                        startRadius: 20,
                        endRadius: 260
                    )
                    RadialGradient(
                        colors: [Palette.glowOrange.opacity(0.75), Color.clear],
                        center: .init(x: 0.2, y: 1.0),
                        startRadius: 10,
                        endRadius: 220
                    )
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func sidebarBackground() -> some View {
        modifier(SidebarBackground())
    }
}

#Preview {
    Text("Sidebar")
        .frame(width: 240, height: 600)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

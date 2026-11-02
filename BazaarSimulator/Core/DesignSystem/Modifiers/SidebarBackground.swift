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

#Preview("Normal") {
    Text("Sidebar")
        .frame(width: 240, height: 600)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Text("Sidebar with a longer label across the column")
        .frame(width: 240, height: 600)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Color.clear
        .frame(width: 240, height: 600)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Text("Dark Sidebar")
        .frame(width: 240, height: 600)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Text("Disabled Sidebar")
        .frame(width: 240, height: 600)
        .disabled(true)
        .sidebarBackground()
        .preferredColorScheme(.dark)
}

import SwiftUI

struct SidebarBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Palette.sidebarBase
                    // A blue glow at the left, a third of the way down.
                    RadialGradient(
                        colors: [Palette.sidebarGlowBlue.opacity(0.9), Color.clear],
                        center: .init(x: 0.0, y: 0.36),
                        startRadius: 10,
                        endRadius: 320
                    )
                    // A warm glow at the bottom right.
                    RadialGradient(
                        colors: [Palette.sidebarGlowWarm.opacity(0.75), Color.clear],
                        center: .init(x: 1.0, y: 0.78),
                        startRadius: 10,
                        endRadius: 340
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

import SwiftUI

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Palette.background
                    // The blue and orange glow sits behind the whole window, so the translucent sidebar shows it.
                    RadialGradient(
                        colors: [Palette.glowBlue.opacity(0.9), Color.clear],
                        center: .init(x: 0.02, y: 0.78),
                        startRadius: 20,
                        endRadius: 420
                    )
                    RadialGradient(
                        colors: [Palette.glowOrange.opacity(0.8), Color.clear],
                        center: .init(x: 0.08, y: 1.0),
                        startRadius: 10,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackground())
    }
}

#Preview("Normal") {
    Text("App Background")
        .frame(width: 300, height: 300)
        .appBackground()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Text("Window Background with long text content")
        .frame(width: 400, height: 300)
        .appBackground()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Color.clear
        .frame(width: 200, height: 200)
        .appBackground()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Text("Dark Mode Window")
        .frame(width: 300, height: 300)
        .appBackground()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Text("Disabled Window")
        .frame(width: 300, height: 300)
        .disabled(true)
        .appBackground()
        .preferredColorScheme(.dark)
}

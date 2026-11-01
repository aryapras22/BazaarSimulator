import SwiftUI

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.l))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l)
                    .stroke(Palette.surfaceBorder, lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View {
        modifier(Card())
    }
}

#Preview("Normal") {
    Text("Card content")
        .padding(Spacing.l)
        .card()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Text("A very long text that demonstrates how the card looks when loaded with content that wraps multiple lines.")
        .padding(Spacing.l)
        .card()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Text("")
        .frame(width: 100, height: 40)
        .card()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Text("Dark Mode Content")
        .padding(Spacing.l)
        .card()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Text("Disabled Content")
        .padding(Spacing.l)
        .card()
        .disabled(true)
        .padding()
        .preferredColorScheme(.dark)
}

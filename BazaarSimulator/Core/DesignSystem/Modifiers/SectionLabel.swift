import SwiftUI

struct SectionLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.sectionLabel)
            .tracking(0.5)
            .foregroundColor(Palette.textSecondary)
    }
}

extension View {
    func sectionLabel() -> some View {
        modifier(SectionLabel())
    }
}

#Preview("Normal") {
    Text("LEGENDS")
        .sectionLabel()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Long Text") {
    Text("SCANNED LEGENDS · 3 Elements · All Layouts")
        .sectionLabel()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Empty Value") {
    Text("")
        .sectionLabel()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dark Mode") {
    Text("UPLOADED · 3 Plans")
        .sectionLabel()
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    Text("DISABLED SECTION")
        .sectionLabel()
        .disabled(true)
        .padding()
        .preferredColorScheme(.dark)
}

import SwiftUI

struct CanvasBackgroundSwatches: View {
    @Binding var selection: CanvasBackground

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(CanvasBackground.allCases) { background in
                swatch(for: background)
            }
        }
        .padding(Spacing.s)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().stroke(Palette.surfaceBorder, lineWidth: 1))
    }

    private func swatch(for background: CanvasBackground) -> some View {
        let isSelected = selection == background
        return Button {
            selection = background
        } label: {
            Circle()
                .fill(background.fill)
                .frame(width: 20, height: 20)
                .overlay(Circle().stroke(Palette.textTertiary, lineWidth: 1))
                .padding(2)
                .overlay(Circle().stroke(isSelected ? Palette.accentIcon : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .help("\(background.title) background")
        .accessibilityLabel("\(background.title) background")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CanvasBackgroundSwatches(selection: .constant(.grey))
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}

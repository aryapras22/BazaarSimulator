import SwiftUI

/// Where PDFs are dropped, or picked from the Finder. It sits inside a card with a dashed border, and dims with the
/// card while it cannot be used yet.
struct DropZone: View {
    let hint: String
    let onChoose: () -> Void
    let onDrop: ([URL]) -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 20))
                .foregroundColor(iconColor)

            Text("Drop PDFs here")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isEnabled ? Palette.textPrimary : Palette.textDisabled)

            Button("Choose files...", action: onChoose)
                .buttonStyle(.secondary)
                .disabled(!isEnabled)

            Text(hint)
                .font(.system(size: 9.5))
                .foregroundColor(isEnabled ? Palette.textTertiary : Palette.textDisabled)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 142)
        .background(isTargeted ? Palette.accent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.m))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            guard isEnabled, !urls.isEmpty else { return false }
            onDrop(urls)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var iconColor: Color {
        if isTargeted { return Palette.accent }
        return isEnabled ? Palette.textPrimary : Palette.textDisabled
    }

    private var borderColor: Color {
        if isTargeted { return Palette.accent }
        return isEnabled ? Palette.textSecondary.opacity(0.55) : Palette.surfaceDisabledBorder
    }
}

#Preview("Enabled") {
    DropZone(hint: "PDF · one legend for all the layouts", onChoose: {}, onDrop: { _ in })
        .padding()
        .frame(width: 340)
        .background(Palette.surface)
        .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    DropZone(hint: "PDF · one page per layout", onChoose: {}, onDrop: { _ in })
        .padding()
        .frame(width: 600)
        .background(Palette.surfaceDisabled)
        .preferredColorScheme(.dark)
        .disabled(true)
}

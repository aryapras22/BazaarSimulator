import SwiftUI

struct DropZone: View {
    let hint: String
    let onChoose: () -> Void
    let onDrop: ([URL]) -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(spacing: Spacing.s) {
            iconView

            Text("Drop PDFs here")
                .font(Typography.body)
                .foregroundColor(isEnabled ? Palette.textPrimary : Palette.textDisabled)

            Button("Choose files...", action: onChoose)
                .buttonStyle(.secondary)
                .disabled(!isEnabled)

            Text(hint)
                .font(Typography.caption)
                .foregroundColor(isEnabled ? Palette.textTertiary : Palette.textDisabled)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(isEnabled ? Palette.surface : Palette.surfaceDisabled)
        .clipShape(RoundedRectangle(cornerRadius: Radius.l))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(borderColor, lineWidth: 1)
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard isEnabled, !urls.isEmpty else { return false }
            onDrop(urls)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var iconView: some View {
        Image(systemName: "arrow.down.doc")
            .font(.system(size: 28))
            .foregroundColor(iconColor)
    }

    private var iconColor: Color {
        if isTargeted {
            return Palette.accent
        }
        return isEnabled ? Palette.accentIcon : Palette.textDisabled
    }

    private var borderColor: Color {
        if isTargeted {
            return Palette.accent
        }
        return isEnabled ? Palette.surfaceBorder : Palette.surfaceDisabledBorder
    }
}

#Preview("Enabled") {
    DropZone(
        hint: "PDF · one legend for all the layouts",
        onChoose: {},
        onDrop: { _ in }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

#Preview("Disabled") {
    DropZone(
        hint: "PDF · one file per layout · up to 6",
        onChoose: {},
        onDrop: { _ in }
    )
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
    .disabled(true)
}

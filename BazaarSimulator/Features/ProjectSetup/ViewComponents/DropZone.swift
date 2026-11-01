import SwiftUI
import UniformTypeIdentifiers

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
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard isEnabled else { return false }
        var collectedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    collectedURLs.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !collectedURLs.isEmpty {
                onDrop(collectedURLs)
            }
        }
        return true
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
    .disabled(true)
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

import SwiftUI

/// One PDF in a list on the upload page. What it shows on the right follows how far reading has got: a progress bar
/// and a cancel button, the counts and a menu, or a failed scan with retry and delete.
struct PlanFileRow: View {
    let display: PlanRowDisplay
    var onEdit: (() -> Void)?
    var onPreview: (() -> Void)?
    /// Asks to delete the file. The page confirms first, except while the file is still being read, where it cancels.
    let onDelete: () -> Void
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "doc")
                .font(.system(size: 16))
                .foregroundColor(display.isReading ? Palette.accentIcon : Palette.accentIcon.opacity(0.85))
                .frame(width: 20)

            Text(display.title)
                .font(.system(size: 12))
                .foregroundColor(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: Spacing.s)

            PlanRowStatusView(status: display.status)

            trailingControls
        }
        .padding(.vertical, 10)
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private var trailingControls: some View {
        switch display.status {
        case .reading, .waiting:
            iconButton("xmark", label: "Cancel", color: Palette.textSecondary, action: onDelete)
        case .failed:
            HStack(spacing: Spacing.s) {
                if let onRetry {
                    iconButton("arrow.clockwise", label: "Retry", color: Palette.destructive, action: onRetry)
                }
                iconButton("trash.fill", label: "Delete", color: Palette.destructive, action: onDelete)
            }
        case .done, .cancelled:
            menuButton
        }
    }

    private func iconButton(_ symbol: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private var menuButton: some View {
        Menu {
            if let onEdit {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    .disabled(!display.isDone)
            }
            if let onPreview {
                Button(action: onPreview) { Label("Preview", systemImage: "eye") }
                    .disabled(!display.isDone)
            }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.textSecondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More for \(display.title)")
    }
}

#Preview("States") {
    VStack(spacing: 0) {
        PlanFileRow(
            display: PlanRowDisplay(id: UUID(), title: "plan-original.pdf", subtitle: "", status: .done(text: "✓ 66 booths · 3 doors")),
            onEdit: {}, onPreview: {}, onDelete: {}
        )
        PlanFileRow(
            display: PlanRowDisplay(id: UUID(), title: "plan-food-court.pdf", subtitle: "", status: .reading(progress: 0.65)),
            onDelete: {}
        )
        PlanFileRow(
            display: PlanRowDisplay(id: UUID(), title: "plan-wide-aisle.pdf", subtitle: "", status: .failed(message: "Couldn't read this plan")),
            onDelete: {}, onRetry: {}
        )
    }
    .padding()
    .frame(width: 640)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

import SwiftUI

struct PlanFileRow: View {
    let display: PlanRowDisplay
    var onEdit: (() -> Void)?
    let onDelete: () -> Void
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: Spacing.m) {
            leadingIcon

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(display.title)
                    .font(Typography.body)
                    .foregroundColor(Palette.textPrimary)
                    .lineLimit(1)

                Text(display.subtitle)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }

            Spacer()

            PlanRowStatusView(status: display.status)

            menuButton
        }
        .padding(.vertical, Spacing.m)
        .frame(minHeight: 45)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if display.hasThumbnail, let data = display.thumbnailData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        } else {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 24))
                .foregroundColor(display.isReading ? Palette.accentMuted : Palette.textSecondary)
                .frame(width: 32, height: 32)
        }
    }

    private var menuButton: some View {
        Menu {
            if case .failed = display.status, let onRetry {
                Button("Retry", action: onRetry)
            }

            if let onEdit {
                Button("Edit", action: onEdit)
                    .disabled(true)
            }

            Button("Delete", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(Typography.body)
                .foregroundColor(Palette.textSecondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

#Preview("Waiting") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "floor_layout_1.pdf",
            subtitle: "Layout 1 · 2.4 MB",
            status: .waiting(text: "Waiting...")
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Reading with Progress") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "floor_layout_2.pdf",
            subtitle: "Layout 2 · 2.6 MB",
            status: .reading(progress: 0.65)
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Reading without Progress") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "floor_layout_3.pdf",
            subtitle: "Layout 3 · 1.8 MB",
            status: .reading(progress: nil)
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Done") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "floor_layout_4.pdf",
            subtitle: "Layout 4 · 3.1 MB",
            status: .done(text: "✓ 66 booths · 3 doors")
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Failed") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "corrupted_plan.pdf",
            subtitle: "Layout 5 · 500 KB",
            status: .failed(message: "Couldn't read this plan")
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

#Preview("Cancelled") {
    PlanFileRow(
        display: PlanRowDisplay(
            id: UUID(),
            title: "floor_layout_6.pdf",
            subtitle: "Layout 6 · 2.2 MB",
            status: .cancelled(text: "Cancelled")
        ),
        onEdit: {},
        onDelete: {}
    )
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

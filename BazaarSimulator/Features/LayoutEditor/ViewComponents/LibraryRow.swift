import SwiftUI

struct LibraryRow: View {
    let row: LibraryRowDisplay
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.m) {
                FootprintThumbnail(
                    footprint: row.footprint,
                    sizeM: row.sizeM,
                    openSides: row.openSides,
                    seats: row.seats,
                    tint: row.tint?.swiftUIColor
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(row.title)
                            .font(Typography.body.bold())
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)

                        if let tint = row.tint {
                            Circle()
                                .fill(tint.swiftUIColor)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Text(row.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(row.id)
    }
}

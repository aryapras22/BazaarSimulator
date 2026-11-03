import SwiftUI

struct BoothGroupRowDisplay: Identifiable, Hashable {
    let id: BoothGroupKind
    let title: String
    let count: Int
    let categoryColors: [LegendColor]
    let extraCategoryCount: Int
}

struct BoothGroupsList: View {
    let nameRows: [BoothGroupRowDisplay]
    let sizeRows: [BoothGroupRowDisplay]
    let onHover: (BoothGroupKind?) -> Void
    let onSelect: (BoothGroupKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            section("By name", rows: nameRows)
            section("By size", rows: sizeRows)
        }
    }

    private func section(_ title: String, rows: [BoothGroupRowDisplay]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textSecondary)
            ForEach(rows) { row in
                BoothGroupRow(row: row, onHover: onHover, onSelect: onSelect)
            }
        }
    }
}

private struct BoothGroupRow: View {
    let row: BoothGroupRowDisplay
    let onHover: (BoothGroupKind?) -> Void
    let onSelect: (BoothGroupKind) -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            onSelect(row.id)
        } label: {
            HStack(spacing: Spacing.s) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(row.categoryColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 8, height: 8)
                    }
                    if row.extraCategoryCount > 0 {
                        Text("+\(row.extraCategoryCount)")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Text(row.title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(row.count)")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(isHovering ? Palette.controlOnSurface : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            onHover(hovering ? row.id : nil)
        }
    }
}

#Preview("Groups list") {
    let red = LegendColor(red: 0.87, green: 0.16, blue: 0.16)
    let green = LegendColor(red: 0.16, green: 0.87, blue: 0.19)
    let blue = LegendColor(red: 0.16, green: 0.4, blue: 0.87)
    let sized = BoothSizeKey(shortM: 2.5, longM: 2.5)
    InspectorPanel(title: "Booth Groups") {
        BoothGroupsList(
            nameRows: [
                BoothGroupRowDisplay(
                    id: .name(prefix: "A"), title: "A", count: 112,
                    categoryColors: [green], extraCategoryCount: 0
                ),
                BoothGroupRowDisplay(
                    id: .name(prefix: "C"), title: "C", count: 16,
                    categoryColors: [red, green, blue], extraCategoryCount: 2
                )
            ],
            sizeRows: [
                BoothGroupRowDisplay(
                    id: .size(sized), title: sized.title, count: 150,
                    categoryColors: [green, blue], extraCategoryCount: 0
                )
            ],
            onHover: { _ in },
            onSelect: { _ in }
        )
    } footer: {
        EmptyView()
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

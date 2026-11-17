import SwiftUI

/// One color of the legend: its swatch, its name, the category the booths of that color belong to, and a trash can.
/// Foods, Goods and Others are all offered.
struct LegendEntryRow: View {
    let name: String
    let color: Color
    let type: BoothType?
    let onTypeChange: (BoothType) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 11, height: 11)

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.textPrimary)
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)

            categoryMenu

            Button(action: onRemove) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Palette.destructive)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove \(name)")
            .accessibilityLabel("Remove \(name)")
        }
        .padding(.vertical, 5)
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(BoothType.allCases, id: \.self) { option in
                Button {
                    onTypeChange(option)
                } label: {
                    if option == type {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        } label: {
            HStack {
                Text(type?.displayName ?? "Choose Category")
                    .font(.system(size: 11))
                    .foregroundColor(Palette.textPrimary)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Palette.textSecondary)
            }
            .padding(.horizontal, Spacing.s)
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(Palette.field, in: RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                    .stroke(Palette.fieldBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel("Category for \(name)")
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        LegendEntryRow(name: "Booth A", color: .red, type: .fnb, onTypeChange: { _ in }, onRemove: {})
        LegendEntryRow(name: "Booth B", color: .green, type: .goods, onTypeChange: { _ in }, onRemove: {})
        LegendEntryRow(name: "Booth C", color: .yellow, type: nil, onTypeChange: { _ in }, onRemove: {})
    }
    .padding()
    .frame(width: 320)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

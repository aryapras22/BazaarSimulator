import SwiftUI

struct CategoryPicker: View {
    let categories: [CategoryOption]
    let title: String
    let isChecked: (CategoryOption) -> Bool
    let onSelect: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Category")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Menu {
                ForEach(categories) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        HStack {
                            Text(option.name)
                            if isChecked(option) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(title)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(Palette.fieldOnSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .stroke(Palette.fieldOnSurfaceBorder, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }
}

#Preview("Category picker") {
    let options = [CategoryOption(id: nil, name: "Unassigned", color: nil)] +
        PreviewLayouts.sampleLegend.entries.map { CategoryOption(id: $0.id, name: $0.name, color: $0.color) }
    VStack(spacing: Spacing.l) {
        CategoryPicker(
            categories: options,
            title: "Fashion & Beauty",
            isChecked: { $0.id == options[2].id },
            onSelect: { _ in }
        )
        CategoryPicker(categories: options, title: "Mixed", isChecked: { _ in false }, onSelect: { _ in })
    }
    .padding()
    .frame(width: 300)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

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

            Picker("Category", selection: selection) {
                if selection.wrappedValue == nil {
                    Text(title).tag(CategoryOption?.none)
                }
                ForEach(categories) { option in
                    Text(option.name).tag(Optional(option))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selection: Binding<CategoryOption?> {
        Binding(
            get: { categories.first(where: isChecked) },
            set: { option in
                if let option { onSelect(option.id) }
            }
        )
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

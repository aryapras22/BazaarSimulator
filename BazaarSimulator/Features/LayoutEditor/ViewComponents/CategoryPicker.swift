import SwiftUI

struct CategoryPicker: View {
    private static let helpText =
        "Booth categories come from the plan's legend, "
        + "and entertainment entries are attractions such as a stage or an information desk."

    let categories: [CategoryOption]
    var entertainmentTypes: [EntertainmentType] = EntertainmentType.allCases
    let title: String
    let currentChoice: CategoryChoice?
    let onSelect: (CategoryChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Text("Category")
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.textPrimary)

                Image(systemName: "info.circle")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .help(Self.helpText)
                    .accessibilityLabel(Self.helpText)
            }

            Picker("Category", selection: selection) {
                if selection.wrappedValue == nil {
                    Text(title).tag(CategoryChoice?.none)
                }
                Section("Booth") {
                    ForEach(categories) { option in
                        Text(option.name).tag(CategoryChoice?.some(.booth(option.id)))
                    }
                }
                if !entertainmentTypes.isEmpty {
                    Section("Entertainment") {
                        ForEach(entertainmentTypes, id: \.self) { type in
                            Text(type.displayName).tag(CategoryChoice?.some(.entertainment(type)))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var selection: Binding<CategoryChoice?> {
        Binding(
            get: { resolvedSelection },
            set: { choice in
                if let choice { onSelect(choice) }
            }
        )
    }

    private var resolvedSelection: CategoryChoice? {
        guard let currentChoice else { return nil }
        switch currentChoice {
        case .booth(let id):
            return categories.contains { $0.id == id } ? currentChoice : nil
        case .entertainment(let type):
            return entertainmentTypes.contains(type) ? currentChoice : nil
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
            currentChoice: .booth(options[2].id),
            onSelect: { _ in }
        )
        CategoryPicker(
            categories: options,
            title: "Information Desk",
            currentChoice: .entertainment(.informationDesk),
            onSelect: { _ in }
        )
        CategoryPicker(
            categories: options,
            entertainmentTypes: [],
            title: "Mixed",
            currentChoice: nil,
            onSelect: { _ in }
        )
    }
    .padding()
    .frame(width: 300)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

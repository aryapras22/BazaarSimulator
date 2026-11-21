import SwiftUI

struct FurnitureTypePicker: View {
    struct Option: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
    }

    static let options: [Option] =
        [Option(id: FurnitureModels.seatingBlockID, name: "Audience Seating")]
        + FurnitureModels.tables.map { Option(id: $0.id, name: $0.name) }

    let selectedID: String
    let onSelect: (String) -> Void

    private var selection: Binding<String> {
        Binding(
            get: { selectedID },
            set: { onSelect($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Type")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Picker("Type", selection: selection) {
                ForEach(Self.options) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Furniture type picker") {
    VStack(spacing: Spacing.l) {
        FurnitureTypePicker(selectedID: FurnitureModels.seatingBlockID, onSelect: { _ in })
        FurnitureTypePicker(selectedID: "table-round-6", onSelect: { _ in })
    }
    .padding()
    .frame(width: 288)
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

import SwiftUI

struct FurnitureTypePicker: View {
    struct Option: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
    }

    static let options: [Option] =
        FurnitureModels.tables.map { Option(id: $0.id, name: $0.name) }
        + [Option(id: FurnitureModels.seatingBlockID, name: "Audience Seating")]

    /// Nil when the selected objects have different types. The menu then reads "Mixed" and checks no option.
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Type")
                .font(Typography.inspectorLabel)
                .foregroundStyle(Palette.textPrimary)

            Group {
                if let selectedID {
                    Picker("Type", selection: Binding(get: { selectedID }, set: { onSelect($0) })) {
                        ForEach(Self.options) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                } else {
                    Menu("Mixed") {
                        ForEach(Self.options) { option in
                            Button(option.name) { onSelect(option.id) }
                        }
                    }
                }
            }
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

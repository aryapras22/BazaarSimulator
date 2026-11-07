import SwiftUI

struct LegendEntryRow: View {
    let name: String
    let color: Color
    let type: BoothType?
    let onTypeChange: (BoothType) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(name)
                .font(Typography.body)
                .foregroundColor(Palette.textPrimary)

            Spacer()

            Picker("Booth type", selection: typeSelection) {
                if type == nil {
                    Text("Choose type").tag(BoothType?.none)
                }
                ForEach(BoothType.allCases, id: \.self) { option in
                    Text(option.displayName).tag(Optional(option))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .accessibilityLabel("Booth type for \(name)")

            Button("Remove", action: onRemove)
                .buttonStyle(.removePill)
                .accessibilityLabel("Remove \(name)")
        }
        .padding(.vertical, Spacing.xs)
    }

    private var typeSelection: Binding<BoothType?> {
        Binding(
            get: { type },
            set: { newType in
                if let newType { onTypeChange(newType) }
            }
        )
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        LegendEntryRow(name: "Booth A", color: .red, type: .fnb, onTypeChange: { _ in }, onRemove: {})
        LegendEntryRow(name: "Booth B", color: .green, type: .fashion, onTypeChange: { _ in }, onRemove: {})
        LegendEntryRow(name: "Booth C", color: .yellow, type: nil, onTypeChange: { _ in }, onRemove: {})
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

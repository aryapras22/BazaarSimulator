import SwiftUI

struct LegendEntryRow: View {
    let name: String
    let color: Color
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

            Button("Remove", action: onRemove)
                .buttonStyle(.removePill)
                .accessibilityLabel("Remove \(name)")
        }
        .padding(.vertical, Spacing.xs)
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        LegendEntryRow(name: "FNB", color: .red) {}
        LegendEntryRow(name: "Fashion", color: .green) {}
        LegendEntryRow(name: "Lifestyle & Hobbies", color: .yellow) {}
    }
    .padding()
    .background(Palette.surface)
    .preferredColorScheme(.dark)
}

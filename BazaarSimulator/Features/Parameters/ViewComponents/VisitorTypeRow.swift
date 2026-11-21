import SwiftUI

/// One visitor type: name, a slider for its share, the percent, and a lock toggle.
struct VisitorTypeRow: View {
    let name: String
    let summary: String
    let color: Color
    let percent: Int
    let isLocked: Bool
    let isEditable: Bool
    let onChange: (Int) -> Void
    let onToggleLock: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Typography.fieldLabel)
                    .foregroundColor(Palette.textPrimary)
                Text(summary)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
                    .lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(percent) },
                    set: { onChange(Int($0.rounded())) }
                ),
                in: 0...100
            )
            .tint(color)
            .disabled(!isEditable)

            CommitField(value: String(percent), alignment: .center) { text in
                if let value = Int(text.trimmingCharacters(in: .whitespaces)) { onChange(value) }
                return String(percent)
            }
            .frame(width: 52)
            .disabled(!isEditable)

            Button(action: onToggleLock) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .foregroundColor(isLocked ? Palette.accentIcon : Palette.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isLocked ? "Unlock \(name)" : "Lock \(name)")
        }
    }
}

#Preview("Normal") {
    VisitorTypeRow(
        name: "Socializer", summary: "Wanders and stops to chat",
        color: Palette.visitorSeries1, percent: 40, isLocked: false, isEditable: true,
        onChange: { _ in }, onToggleLock: {}
    )
    .padding()
    .frame(width: 520)
    .preferredColorScheme(.dark)
}

#Preview("Locked") {
    VisitorTypeRow(
        name: "Purpose Buyer", summary: "Heads straight to planned stops and leaves quickly",
        color: Palette.visitorSeries4, percent: 25, isLocked: true, isEditable: false,
        onChange: { _ in }, onToggleLock: {}
    )
    .padding()
    .frame(width: 520)
    .preferredColorScheme(.dark)
}

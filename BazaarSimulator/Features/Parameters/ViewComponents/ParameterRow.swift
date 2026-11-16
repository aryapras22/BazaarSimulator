import SwiftUI

/// A titled setting: title and hint on the left, the control on the right.
struct ParameterRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(Typography.fieldLabel)
                    .foregroundColor(Palette.textPrimary)
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundColor(Palette.textSecondary)
            }
            .frame(width: 340, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.m)
    }
}

#Preview("Normal") {
    ParameterRow(title: "Total Visitors", subtitle: "Estimated number of visitors per day.") {
        CommitField(value: "5000", suffix: "people") { $0 }
            .frame(width: 230)
    }
    .padding()
    .frame(width: 900)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

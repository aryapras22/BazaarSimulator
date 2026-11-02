import SwiftUI

struct CalloutCard: View {
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Tip: \(message)")
                .font(Typography.body)
                .foregroundStyle(Palette.tipText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(actionTitle)
                    .font(Typography.inspectorLabel)
                    .foregroundStyle(Palette.tipText)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.s)
                            .fill(Palette.tipButton)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.m)
                .fill(Palette.tipBackground)
        )
    }
}

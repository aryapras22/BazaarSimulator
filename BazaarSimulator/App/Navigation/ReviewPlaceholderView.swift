import SwiftUI

struct ReviewPlaceholderView: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            Text("Layout Review")
                .font(Typography.title)
                .foregroundColor(Palette.textPrimary)

            Text("Layout review and editor will be available here.")
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

#Preview {
    ReviewPlaceholderView()
        .preferredColorScheme(.dark)
}

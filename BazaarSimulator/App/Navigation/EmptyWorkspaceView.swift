import SwiftUI

struct EmptyWorkspaceView: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36))
                .foregroundColor(Palette.textSecondary)
                .padding(.bottom, Spacing.xs)

            Text("Your Workspace is Ready")
                .font(Typography.emptyTitle)
                .foregroundColor(Palette.textPrimary)

            Text("Select the + button in the sidebar to create your first project.")
                .font(Typography.subtitle)
                .foregroundColor(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

#Preview {
    EmptyWorkspaceView()
        .preferredColorScheme(.dark)
}

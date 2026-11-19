import SwiftUI

/// Shown when no project is open: the first thing a new user sees, and what remains after the last project is deleted.
struct EmptyWorkspaceView: View {
    var hasProjects = false
    var onAddProject: () -> Void = {}

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "square.on.square")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(Palette.textSecondary)

            Text(hasProjects ? "Choose a Project" : "Create Your First Project")
                .font(Typography.emptyTitle)
                .foregroundColor(Palette.textPrimary)

            if hasProjects {
                Text("Select a project in the sidebar, or add a new one.")
                    .font(Typography.subtitle)
                    .foregroundColor(Palette.textSecondary)
            }

            Button(action: onAddProject) {
                Label("Add Project", systemImage: "plus")
            }
            .buttonStyle(.highlight)
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .underToolbarInWindow()
    }
}

#Preview("No project") {
    EmptyWorkspaceView()
        .preferredColorScheme(.dark)
}

#Preview("Projects exist") {
    EmptyWorkspaceView(hasProjects: true)
        .preferredColorScheme(.dark)
}

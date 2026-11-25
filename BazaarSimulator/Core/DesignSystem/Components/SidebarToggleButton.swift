import SwiftUI

/// The small button that shows or hides the sidebar.
struct SidebarToggleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: ToolbarMetrics.iconFontSize, weight: .regular))
                .foregroundColor(Palette.textSecondary)
                .frame(width: ToolbarMetrics.controlSize, height: ToolbarMetrics.controlSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show or hide the sidebar")
        .accessibilityLabel("Toggle sidebar")
    }
}

#Preview {
    SidebarToggleButton(action: {})
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}

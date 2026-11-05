import SwiftUI

struct EditorHintStrip: View {
    let tool: EditorTool
    var message: String?

    var body: some View {
        Text(message ?? hintText(for: tool))
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: Radius.s)
                    .fill(Palette.surface.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.s)
                    .stroke(Palette.surfaceBorder, lineWidth: 1)
            )
    }

    private func hintText(for tool: EditorTool) -> String {
        switch tool {
        case .select:
            return "Click to select · Drag to move · Marquee on floor · Space-drag to pan"
        case .drawWall:
            return "Click to place segment · Shift for angle lock · Return or double-click to finish · Escape to cancel"
        case .room:
            return "Drag rectangle to create room walls · Escape to cancel"
        case .floor:
            return "Drag rectangle to define floor slab · Escape to cancel"
        case .row:
            return "Drag along wall or aisle to place row of booths · Escape to cancel"
        case .fill:
            return "Drag rectangle to fill region with booths · Escape to cancel"
        case .placeDoor:
            return "Click on wall to place door · Shift for free move · Escape to cancel"
        case .place:
            return "Click to place · Shift for free move · Escape to cancel"
        case .blockedArea:
            return "Drag to define blocked area · Escape to cancel"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.s) {
        EditorHintStrip(tool: .select)
        EditorHintStrip(tool: .drawWall(itemID: "wall"))
        EditorHintStrip(tool: .placeDoor(itemID: "door"))
        EditorHintStrip(tool: .place(.catalog("table")))
        EditorHintStrip(tool: .blockedArea)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

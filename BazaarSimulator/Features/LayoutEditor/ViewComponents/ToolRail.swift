import SwiftUI

enum ToolRailItem: CaseIterable, Identifiable, Sendable {
    case select
    case wall
    case door
    case library
    case blockedArea

    var id: Self { self }

    var title: String {
        switch self {
        case .select: return "Select (V)"
        case .wall: return "Wall (W)"
        case .door: return "Door (D)"
        case .library: return "Library / Place booth (B)"
        case .blockedArea: return "Blocked Area (X)"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .wall: return "line.diagonal"
        case .door: return "door.left.hand.open"
        case .library: return "square.grid.2x2"
        case .blockedArea: return "square.dashed"
        }
    }
}

struct ToolRail: View {
    let activeTool: EditorTool
    let isSidePanelOpen: Bool
    let onSelect: (ToolRailItem) -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(ToolRailItem.allCases) { item in
                toolButton(for: item)
            }

            Spacer()

            spacePanHelper
        }
        .padding(.vertical, Spacing.m)
        .padding(.horizontal, Spacing.xs)
        .frame(width: 48)
        .frame(maxHeight: .infinity)
        .background(Palette.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Palette.surfaceBorder)
                .frame(width: 1)
        }
    }

    private func isItemActive(_ item: ToolRailItem) -> Bool {
        switch item {
        case .select:
            return activeTool == .select
        case .wall:
            if case .drawWall = activeTool { return true }
            return false
        case .door:
            if case .placeDoor = activeTool { return true }
            return false
        case .library:
            if case .place = activeTool { return true }
            return isSidePanelOpen
        case .blockedArea:
            return activeTool == .blockedArea
        }
    }

    private func toolButton(for item: ToolRailItem) -> some View {
        let isActive = isItemActive(item)
        return Button {
            onSelect(item)
        } label: {
            Image(systemName: item.systemImage)
                .font(Typography.body)
                .foregroundStyle(isActive ? Palette.textPrimary : Palette.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(isActive ? Palette.segmentedSelected : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.s)
                        .stroke(isActive ? Palette.highlight : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(item.title)
        .accessibilityLabel(item.title)
    }

    private var spacePanHelper: some View {
        VStack(spacing: 2) {
            Image(systemName: "hand.raised")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 36, height: 28)

            Text("Space")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
        .help("Hold Space to pan")
        .accessibilityLabel("Hold Space to pan")
    }
}

#Preview {
    HStack(spacing: 0) {
        ToolRail(
            activeTool: .select,
            isSidePanelOpen: false,
            onSelect: { _ in }
        )
        Color.black
    }
    .frame(width: 200, height: 400)
    .preferredColorScheme(.dark)
}

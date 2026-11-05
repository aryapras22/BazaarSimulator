import SwiftUI

enum ToolRailItem: CaseIterable, Identifiable, Sendable {
    case select
    case wall
    case room
    case library

    var id: Self { self }

    var title: String {
        switch self {
        case .select: return "Select (V)"
        case .wall: return "Wall (W)"
        case .room: return "Room (R)"
        case .library: return "Library (B)"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .wall: return "line.diagonal"
        case .room: return "rectangle"
        case .library: return "square.grid.2x2"
        }
    }

    static func items(for layer: EditorLayer) -> [ToolRailItem] {
        switch layer {
        case .structure:
            return [.select, .wall, .room, .library]
        case .booths:
            return [.select, .library]
        }
    }
}

struct ToolRail: View {
    let layer: EditorLayer
    let activeTool: EditorTool
    let isSidePanelOpen: Bool
    let onSelect: (ToolRailItem) -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(ToolRailItem.items(for: layer)) { item in
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
        case .room:
            if case .room = activeTool { return true }
            return false
        case .library:
            if case .place = activeTool { return true }
            return isSidePanelOpen
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
            layer: .structure,
            activeTool: .select,
            isSidePanelOpen: false,
            onSelect: { _ in }
        )
        Color.black
    }
    .frame(width: 200, height: 400)
    .preferredColorScheme(.dark)
}

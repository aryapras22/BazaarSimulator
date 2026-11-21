import SwiftUI

/// The buttons that add things to the plan, in a column beside the inspector. The Floor Plan tab has booth and table.
/// The Structure tab has wall, block, door, and restricted area.
struct EditorToolButtons: View {
    let layer: EditorLayer
    let isActive: (EditorAddTool) -> Bool
    let isAvailable: (EditorAddTool) -> Bool
    let onSelect: (EditorAddTool) -> Void

    @State private var hoveredTool: EditorAddTool?

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(EditorAddTool.tools(for: layer)) { item in
                button(for: item)
            }
        }
        .onChange(of: layer) { hoveredTool = nil }
    }

    private func button(for item: EditorAddTool) -> some View {
        ZStack {
            toolButton(for: item)
        }
        .onHover { isHovering in
            if isHovering {
                hoveredTool = item
            } else if hoveredTool == item {
                hoveredTool = nil
            }
        }
        .overlay(alignment: .trailing) {
            if hoveredTool == item {
                hoverLabel(item.title)
                    .padding(.trailing, 40 + Spacing.s)
                    .allowsHitTesting(false)
            }
        }
    }

    private func hoverLabel(_ title: String) -> some View {
        Text(title)
            .font(Typography.caption)
            .foregroundColor(Palette.textPrimary)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().stroke(Palette.surfaceBorder, lineWidth: 1))
            .fixedSize()
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func toolIcon(for item: EditorAddTool) -> some View {
        switch item.icon {
        case .system(let name) where item == .table:
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 15, weight: .medium))
        case .asset(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
    }

    private func toolButton(for item: EditorAddTool) -> some View {
        let active = isActive(item)
        return Button {
            onSelect(item)
        } label: {
            toolIcon(for: item)
                .foregroundColor(Palette.textPrimary.opacity(isAvailable(item) ? 1 : 0.35))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(active ? Color(hex: 0x3D5073) : Color(hex: 0x2A3A56))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(active ? Palette.highlight : Color(hex: 0x40536F), lineWidth: active ? 1.5 : 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable(item))
        .help(item.title)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

#Preview("Floor Plan") {
    EditorToolButtons(layer: .booths, isActive: { $0 == .table }, isAvailable: { _ in true }, onSelect: { _ in })
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}

#Preview("Structure") {
    EditorToolButtons(layer: .structure, isActive: { _ in false }, isAvailable: { _ in true }, onSelect: { _ in })
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}

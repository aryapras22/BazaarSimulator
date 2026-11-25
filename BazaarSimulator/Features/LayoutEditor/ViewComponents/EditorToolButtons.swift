import SwiftUI

/// The tool column beside the inspector. The Floor Plan tab has booth, chair, and popularity.
/// The Structure tab has wall, block, door, and restricted area.
struct EditorToolButtons: View {
    let layer: EditorLayer
    let isActive: (EditorAddTool) -> Bool
    let isAvailable: (EditorAddTool) -> Bool
    let onSelect: (EditorAddTool) -> Void
    var isPopularityActive: Bool = false
    var onTogglePopularity: () -> Void = {}

    private enum HoveredItem: Equatable {
        case tool(EditorAddTool)
        case popularity

        var title: String {
            switch self {
            case .tool(let item): item.title
            case .popularity: "Popularity"
            }
        }
    }

    @State private var hoveredItem: HoveredItem?

    var body: some View {
        VStack(spacing: Spacing.s) {
            ForEach(EditorAddTool.tools(for: layer)) { item in
                tile(
                    .tool(item),
                    isActive: isActive(item),
                    isAvailable: isAvailable(item),
                    action: { onSelect(item) },
                    icon: { toolIcon(for: item) }
                )
            }
            if layer == .booths {
                tile(
                    .popularity,
                    isActive: isPopularityActive,
                    action: onTogglePopularity,
                    icon: { popularityIcon }
                )
            }
        }
        .onChange(of: layer) { hoveredItem = nil }
    }

    private func tile<Icon: View>(
        _ item: HoveredItem,
        isActive: Bool,
        isAvailable: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        ZStack {
            Button(action: action) {
                icon()
                    .foregroundColor(Palette.textPrimary.opacity(isAvailable ? 1 : 0.35))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                            .fill(isActive ? Color(hex: 0x3D5073) : Color(hex: 0x2A3A56))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                            .strokeBorder(
                                isActive ? Palette.highlight : Color(hex: 0x40536F),
                                lineWidth: isActive ? 1.5 : 1
                            )
                    )
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                    .contentShape(RoundedRectangle(cornerRadius: Radius.s, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .help(item.title)
            .accessibilityLabel(item.title)
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
        .onHover { isHovering in
            if isHovering {
                hoveredItem = item
            } else if hoveredItem == item {
                hoveredItem = nil
            }
        }
        .overlay(alignment: .trailing) {
            if hoveredItem == item {
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

    // SF Symbols has no person-with-star glyph, so the star is stacked above a person.
    private var popularityIcon: some View {
        VStack(spacing: 0) {
            Image(systemName: "star.fill")
                .font(.system(size: 7, weight: .bold))
            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .medium))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func toolIcon(for item: EditorAddTool) -> some View {
        switch item.icon {
        case .system(let name) where item == .chair:
            Image(systemName: name)
                .font(.system(size: 17, weight: .medium))
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
}

#Preview("Floor Plan") {
    HStack(spacing: Spacing.l) {
        EditorToolButtons(
            layer: .booths,
            isActive: { $0 == .chair },
            isAvailable: { _ in true },
            onSelect: { _ in },
            isPopularityActive: false,
            onTogglePopularity: {}
        )
        EditorToolButtons(
            layer: .booths,
            isActive: { _ in false },
            isAvailable: { _ in true },
            onSelect: { _ in },
            isPopularityActive: true,
            onTogglePopularity: {}
        )
    }
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

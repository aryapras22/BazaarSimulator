import SwiftUI

/// The top of the editor: back to the analysis, which layout this is, the Floor Plan and Structure tabs, and
/// undo and redo.
struct EditorHeaderBar: View {
    @Bindable var viewModel: LayoutEditorViewModel

    var body: some View {
        HStack(spacing: Spacing.m) {
            backButton

            layoutTitle

            Spacer(minLength: Spacing.l)

            if let chip = placingChipTitle {
                placingChip(chip)
            }

            layerTabs

            Spacer(minLength: Spacing.l)

            HStack(spacing: Spacing.s) {
                roundButton("arrow.uturn.backward", label: "Undo", help: "Undo (⌘Z)", enabled: viewModel.canUndo) {
                    viewModel.undo()
                }
                roundButton("arrow.uturn.forward", label: "Redo", help: "Redo (⇧⌘Z / ⌘Y)", enabled: viewModel.canRedo) {
                    viewModel.redo()
                }
            }
        }
        .frame(height: 40)
    }

    // MARK: Pieces

    private var backButton: some View {
        Button {
            viewModel.requestBack()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Palette.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(hex: 0x1C2A40)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Back to Analysis")
        .accessibilityLabel("Back to Analysis")
    }

    /// Which layout is being edited is chosen from the upload page, so the title is only a label here.
    private var layoutTitle: some View {
        let index = (viewModel.layouts.firstIndex { $0.id == viewModel.activeLayoutID } ?? 0) + 1
        return Text("Layout \(index)")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Palette.textPrimary)
    }

    private var layerTabs: some View {
        HStack(spacing: 0) {
            ForEach(Self.tabOrder, id: \.self) { layer in
                let selected = viewModel.activeLayer == layer
                Button {
                    viewModel.selectLayer(layer)
                } label: {
                    Text(Self.title(of: layer))
                        .font(.system(size: 13, weight: selected ? .semibold : .medium))
                        .foregroundColor(selected ? Palette.textPrimary : Palette.textSecondary)
                        .frame(width: 168, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? Color(hex: 0x3A4A66) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color(hex: 0x1A2740), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(hex: 0x2F4260), lineWidth: 1))
        .help("Layer (⌘1 Structure, ⌘2 Floor Plan)")
    }

    private func roundButton(
        _ symbol: String, label: String, help: String, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Palette.textPrimary.opacity(enabled ? 1 : 0.35))
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color(hex: 0x1C2A40)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
        .accessibilityLabel(label)
    }

    private func placingChip(_ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(text)
                .font(Typography.caption)
                .foregroundColor(Palette.textPrimary)
            Button {
                viewModel.selectTool(.select)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Palette.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Stop placing (Esc)")
            .accessibilityLabel("Stop placing")
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs + 2)
        .background(Color(hex: 0x1C2A40), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
    }

    // MARK: Words

    /// The Floor Plan tab is the booths layer. It comes first, as in the design.
    static let tabOrder: [EditorLayer] = [.booths, .structure]

    static func title(of layer: EditorLayer) -> String {
        layer == .booths ? "Floor Plan" : "Structure"
    }

    private var placingChipTitle: String? {
        switch viewModel.tool {
        case .place(let source):
            switch source {
            case .template(let template):
                let name = viewModel.legend.entries.first { $0.id == template.categoryID }?.name ?? "Booth"
                return "Placing \(name) booth · Esc to stop"
            case .catalog(let itemID):
                let name = ObjectCatalog.item(itemID)?.name ?? "item"
                return "Placing \(name) · Esc to stop"
            }
        case .drawWall:
            return "Drawing wall · Esc to stop"
        case .room:
            return "Drawing room · Esc to stop"
        case .placeDoor:
            return "Placing door · Esc to stop"
        case .blockedArea:
            return "Marking restricted area · Esc to stop"
        default:
            return nil
        }
    }
}

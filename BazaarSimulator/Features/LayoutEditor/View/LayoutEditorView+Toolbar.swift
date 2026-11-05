import SwiftUI

extension LayoutEditorView {
    @ToolbarContentBuilder
    var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: Spacing.m) {
                Button {
                    viewModel.requestBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back to Project Setup")
                .help("Back to Project Setup")

                HStack(spacing: Spacing.xs) {
                    Text(viewModel.projectName)
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)

                    Text("·")
                        .foregroundStyle(Palette.textSecondary)

                    if viewModel.layouts.count > 1 {
                        Menu {
                            ForEach(Array(viewModel.layouts.enumerated()), id: \.element.id) { index, item in
                                Button("Layout \(index + 1) · \(item.name)") {
                                    viewModel.selectLayout(item.id)
                                }
                            }
                        } label: {
                            let activeIndex = viewModel.layouts.firstIndex {
                                $0.id == viewModel.activeLayoutID
                            } ?? 0
                            let activeName = viewModel.activeLayout?.name ?? ""
                            Text("Layout \(activeIndex + 1) · \(activeName)")
                                .font(Typography.body)
                        }
                    } else {
                        Text(viewModel.activeLayout?.name ?? "")
                            .font(Typography.body)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                HStack(spacing: Spacing.xs) {
                    Button {
                        viewModel.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!viewModel.canUndo)
                    .help("Undo (⌘Z)")
                    .accessibilityLabel("Undo")

                    Button {
                        viewModel.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!viewModel.canRedo)
                    .help("Redo (⇧⌘Z)")
                    .accessibilityLabel("Redo")
                }
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: Spacing.m) {
                SegmentedTabs(
                    selection: Binding(
                        get: { viewModel.tab },
                        set: { viewModel.selectTab($0) }
                    ),
                    tabs: EditorTab.allCases,
                    title: \.title
                )

                ViewPresetPicker(
                    selection: Binding(
                        get: { viewModel.viewPreset },
                        set: { _ in }
                    ),
                    onSelect: { preset in
                        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                        viewModel.selectViewPreset(preset, reduceMotion: reduceMotion, viewSize: canvasSize)
                    }
                )
            }
        }

        if let placingChipTitle {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.xs) {
                    Text(placingChipTitle)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Button {
                        viewModel.selectTool(.select)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(Palette.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(Palette.surfaceBorder, lineWidth: 1)
                )
            }
        }
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
        case .placeDoor:
            return "Placing door · Esc to stop"
        default:
            return nil
        }
    }
}

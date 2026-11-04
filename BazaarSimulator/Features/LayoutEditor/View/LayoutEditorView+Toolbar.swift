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

        if viewModel.tab == .floorPlan {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.s) {
                    if let placingChipTitle {
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

                    HStack(spacing: Spacing.xs) {
                        ForEach(EditorTool.primaryTools, id: \.self) { tool in
                            Button {
                                viewModel.selectTool(tool)
                            } label: {
                                Image(systemName: tool.systemImage)
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.textPrimary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.s)
                                            .fill(viewModel.tool == tool ? Palette.segmentedSelected : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tool.title)
                            .help(tool.title)
                        }
                    }
                }
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

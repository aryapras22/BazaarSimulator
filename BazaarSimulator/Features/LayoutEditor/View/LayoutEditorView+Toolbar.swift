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
                .accessibilityLabel("Back to Analysis")

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
            SegmentedTabs(
                selection: Binding(
                    get: { viewModel.tab },
                    set: { viewModel.selectTab($0) }
                ),
                tabs: EditorTab.allCases,
                title: \.title
            )
        }

        if viewModel.tab == .floorPlan {
            ToolbarItem(placement: .primaryAction) {
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

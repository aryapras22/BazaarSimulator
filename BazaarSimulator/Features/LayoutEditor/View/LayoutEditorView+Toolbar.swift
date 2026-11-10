import SwiftUI

extension LayoutEditorView {
    @ToolbarContentBuilder
    var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                viewModel.requestBack()
            } label: {
                Label("Back to Analysis", systemImage: "chevron.left")
            }
            .help("Back to Analysis")
        }

        if viewModel.layouts.count > 1 {
            ToolbarItem(placement: .navigation) {
                layoutMenu
            }
        }

        ToolbarSpacer(.fixed, placement: .navigation)

        ToolbarItemGroup(placement: .navigation) {
            Button {
                viewModel.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!viewModel.canUndo)
            .help("Undo (⌘Z)")

            Button {
                viewModel.redo()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .help("Redo (⇧⌘Z)")
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: Spacing.l) {
                layerPicker
                viewPresetPicker
            }
        }

        if let placingChipTitle {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Spacing.xs) {
                    Text(placingChipTitle)
                        .font(Typography.caption)
                    Button {
                        viewModel.selectTool(.select)
                    } label: {
                        Label("Stop placing", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .help("Stop placing (Esc)")
                }
            }
        }
    }

    private var layoutMenu: some View {
        Menu {
            ForEach(Array(viewModel.layouts.enumerated()), id: \.element.id) { index, item in
                Button("Layout \(index + 1) · \(item.name)") {
                    viewModel.selectLayout(item.id)
                }
            }
        } label: {
            let activeIndex = viewModel.layouts.firstIndex { $0.id == viewModel.activeLayoutID } ?? 0
            Text("Layout \(activeIndex + 1) · \(viewModel.activeLayout?.name ?? "")")
        }
        .help("Switch layout")
    }

    private var layerPicker: some View {
        Picker(
            "Layer",
            selection: Binding(get: { viewModel.activeLayer }, set: { viewModel.selectLayer($0) })
        ) {
            ForEach(EditorLayer.allCases, id: \.self) { layer in
                Text(layer.title).tag(layer)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Layer (⌘1 Structure, ⌘2 Booths)")
    }

    private var viewPresetPicker: some View {
        Picker(
            "View",
            selection: Binding(
                get: { viewModel.viewPreset },
                set: { preset in
                    let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                    viewModel.selectViewPreset(preset, reduceMotion: reduceMotion, viewSize: canvasSize)
                }
            )
        ) {
            ForEach(ViewPreset.allCases, id: \.self) { preset in
                Text(preset.title).tag(preset)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("View (1 Plan, 2 3D)")
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
        default:
            return nil
        }
    }
}

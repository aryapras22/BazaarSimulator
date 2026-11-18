import SwiftUI
import simd

struct LayoutEditorView: View {
    @Bindable var viewModel: LayoutEditorViewModel
    @State var canvasViewSize: SIMD2<Double> = SIMD2<Double>(960, 640)
    @State private var pointer = CanvasPointer()
    @State private var isSidePanelVisible = true
    @FocusState private var isCanvasFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pageClearsToolbar) private var pageClearsToolbar

    /// Room kept at the right of the canvas for the tool buttons: their width and a gap on each side.
    private static let toolButtonsWidth: CGFloat = 64

    var body: some View {
        // The inspector runs the whole height of the window, so the header, with undo and redo, ends where it starts.
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                EditorHeaderBar(viewModel: viewModel)
                    // The window's own buttons and the sidebar toggle float over the top left, so the bar starts after them.
                    .padding(.leading, pageClearsToolbar ? Spacing.l : 150)
                    // Undo and redo end above the tool buttons, with the same gap to the inspector.
                    .padding(.trailing, InspectorPanelMetrics.margin + Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)

                ZStack(alignment: .topTrailing) {
                    viewportArea
                        .padding(.trailing, Self.toolButtonsWidth)

                    EditorToolButtons(
                        layer: viewModel.activeLayer,
                        isActive: { viewModel.isActive($0) },
                        isAvailable: { viewModel.tool(for: $0) != nil },
                        onSelect: { viewModel.toggle($0) }
                    )
                    .padding(.top, InspectorPanelMetrics.margin + Spacing.s)
                    .padding(.trailing, InspectorPanelMetrics.margin)
                }
            }

            LayoutInspectorColumn(
                viewModel: viewModel,
                onFocusIssue: { viewModel.focusIssue($0, in: canvasViewSize) }
            )
            .padding(InspectorPanelMetrics.margin)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 800, minHeight: 560)
        .background(Palette.background.ignoresSafeArea())
        .underToolbarInWindow()
        .navigationTitle(viewModel.projectName)
        .navigationSubtitle(viewModel.layouts.count > 1 ? "" : viewModel.activeLayout?.name ?? "")
        .focusedSceneValue(\.editorCommandActions, commandActions)
        .onKeyPress(keys: [.delete, .deleteForward, .macDelete]) { _ in
            // Placed on the whole editor so Delete works after a click in the side panels; a text field being edited keeps it.
            guard !(NSApp.keyWindow?.firstResponder is NSText) else { return .ignored }
            viewModel.deleteCurrentSelection()
            return .handled
        }
        .confirmationDialog(groupDeleteDialogTitle, isPresented: isGroupDeletePending, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { viewModel.deleteGroupSelection() }
            Button("Cancel", role: .cancel) { viewModel.pendingGroupDelete = nil }
        }
    }
}

extension LayoutEditorView {
    private var panelAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    var canvasSize: CGSize {
        CGSize(width: canvasViewSize.x, height: canvasViewSize.y)
    }

    private var canvasSnapshot: CanvasDisplaySnapshot {
        CanvasDisplaySnapshot(
            layout: viewModel.activeLayout ?? Layout(name: "", sizeM: SIMD2<Double>(20, 20)),
            legend: viewModel.legend,
            activeLayer: viewModel.activeLayer,
            hiddenLayers: viewModel.hiddenLayers,
            showVisitorFlow: viewModel.showVisitorFlow,
            selectionID: viewModel.selectionID,
            hoverID: viewModel.hoverID,
            groupMemberIDs: viewModel.groupMemberIDs,
            hoveredGroupMemberIDs: viewModel.hoveredGroupMemberIDs,
            groupClusters: viewModel.groupClusters,
            issues: viewModel.canvasIssueSnapshot,
            hoverWorld: pointer.world,
            background: viewModel.canvasBackground,
            showsAttractiveness: viewModel.showsAttractiveness
        )
    }

    private var commandActions: EditorCommandActions {
        let selected = viewModel.selectedObject
        let isMovable = selected?.kind.isMovable == true
        let isRotatable = selected?.kind.isRotatable == true
        return EditorCommandActions(
            canUndo: viewModel.canUndo,
            canRedo: viewModel.canRedo,
            hasSelection: isMovable || viewModel.groupSelection != nil,
            canDuplicate: isMovable,
            canRotate: isRotatable,
            undo: { viewModel.undo() },
            redo: { viewModel.redo() },
            deleteSelected: { viewModel.deleteCurrentSelection() },
            duplicateSelected: { viewModel.duplicateSelected() },
            rotateSelected: { viewModel.rotateSelected() },
            zoomIn: { viewModel.zoomIn(in: canvasViewSize) },
            zoomOut: { viewModel.zoomOut(in: canvasViewSize) },
            fitToView: { viewModel.fitToView(in: canvasViewSize) },
            selectStructureLayer: { viewModel.selectLayer(.structure) },
            selectBoothsLayer: { viewModel.selectLayer(.booths) }
        )
    }

    private var viewportArea: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                canvasView(proxy: proxy)
            }

            CanvasRulers(
                transform: viewModel.transform,
                pointer: pointer,
                selectionBounds: viewModel.selectionBounds
            )

            CanvasOverlays(
                pointer: pointer,
                pointsPerMetre: viewModel.transform.scale,
                tool: viewModel.tool,
                message: viewModel.transientHint,
                background: $viewModel.canvasBackground,
                showsAttractiveness: viewModel.activeLayer == .booths ? $viewModel.showsAttractiveness : nil,
                onZoomIn: { viewModel.zoomIn(in: canvasViewSize) },
                onZoomOut: { viewModel.zoomOut(in: canvasViewSize) },
                onFit: { viewModel.fitToView(in: canvasViewSize) }
            )

            if !viewModel.flowBannerIssues.isEmpty {
                VStack(spacing: Spacing.xs) {
                    ForEach(viewModel.flowBannerIssues, id: \.self) { banner in
                        Text(banner)
                            .font(Typography.body)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.xs + 2)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.s)
                                    .fill(Palette.destructive)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.l)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func canvasView(proxy: GeometryProxy) -> some View {
        attachCanvasShortcuts(to: makeLayoutCanvasView())
            .onAppear {
                let size = SIMD2<Double>(Double(proxy.size.width), Double(proxy.size.height))
                canvasViewSize = size
                viewModel.fitIfNeeded(in: size)
                viewModel.refreshDerivedState()
                isCanvasFocused = true
            }
            .onGeometryChange(for: CGSize.self, of: \.size) { newSize in
                let size = SIMD2<Double>(Double(newSize.width), Double(newSize.height))
                canvasViewSize = size
                viewModel.refitIfUntouched(in: size)
            }
            .onChange(of: viewModel.activeLayoutID) { _, _ in
                viewModel.fitIfNeeded(in: SIMD2<Double>(Double(proxy.size.width), Double(proxy.size.height)))
            }
            .onChange(of: viewModel.selectionID) { _, newID in
                if newID != nil { isCanvasFocused = true }
            }
    }

    private func attachCanvasShortcuts(to content: some View) -> some View {
        content
            .onKeyPress(.escape) { handleEscapeKey() }
            .onKeyPress(characters: CharacterSet(charactersIn: "vV")) { _ in
                handleToolRailSelection(.select)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "wW")) { _ in
                guard viewModel.activeLayer == .structure else { return .ignored }
                handleToolRailSelection(.wall)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "rR")) { _ in handleRKey() }
            .onKeyPress(characters: CharacterSet(charactersIn: "fF")) { _ in handleFKey() }
            .onKeyPress(characters: CharacterSet(charactersIn: "dD")) { _ in
                guard viewModel.activeLayer == .structure else { return .ignored }
                openLibrary()
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "bB")) { _ in
                handleToolRailSelection(.library)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "xX")) { _ in
                guard viewModel.activeLayer == .structure else { return .ignored }
                openLibrary()
                return .handled
            }
    }

    private func handleEscapeKey() -> KeyPress.Result {
        if viewModel.tool != .select {
            viewModel.cancelActiveTool()
            return .handled
        }
        return .ignored
    }

    private func handleRKey() -> KeyPress.Result {
        if viewModel.activeLayer == .structure {
            handleToolRailSelection(.room)
            return .handled
        } else if viewModel.activeLayer == .booths {
            handleToolRailSelection(.row)
            return .handled
        }
        return .ignored
    }

    private func handleFKey() -> KeyPress.Result {
        guard viewModel.activeLayer == .booths else { return .ignored }
        handleToolRailSelection(.fill)
        return .handled
    }

    private func openLibrary() {
        withAnimation(panelAnimation) {
            isSidePanelVisible = true
            viewModel.inspectorPanelTab = .library
        }
    }

    private func handleToolRailSelection(_ item: ToolRailItem) {
        switch item {
        case .select:
            viewModel.selectTool(.select)
        case .wall:
            viewModel.selectTool(.drawWall(itemID: viewModel.selectedWallItemID))
        case .room:
            viewModel.selectTool(.room(itemID: viewModel.selectedWallItemID))
        case .row:
            viewModel.selectTool(.row(sizeM: SIMD2(2.5, 2.5)))
        case .fill:
            viewModel.selectTool(.fill(sizeM: SIMD2(2.5, 2.5)))
        case .library:
            withAnimation(panelAnimation) {
                if !isSidePanelVisible {
                    isSidePanelVisible = true
                    viewModel.inspectorPanelTab = .library
                    if viewModel.activeLayer == .booths, let first = viewModel.cachedBoothTemplates.first {
                        viewModel.selectTool(.place(.template(first)))
                    }
                } else if viewModel.inspectorPanelTab != .library {
                    viewModel.inspectorPanelTab = .library
                } else {
                    isSidePanelVisible = false
                }
            }
        }
    }

    @ViewBuilder
    private func makeLayoutCanvasView() -> some View {
        LayoutCanvasView(
            snapshot: canvasSnapshot,
            transform: $viewModel.transform,
            isFocused: $isCanvasFocused,
            dragState: viewModel.dragState,
            tool: viewModel.tool,
            onPointerPress: { viewModel.handlePointerPress($0) },
            onPointerMove: { viewModel.handlePointerMove($0) },
            onPointerRelease: { viewModel.handlePointerRelease($0) },
            onPointerDoubleClick: { viewModel.handlePointerDoubleClick($0) },
            onCanvasKey: { viewModel.handleCanvasKey($0) },
            onCancelTool: { viewModel.cancelActiveTool() },
            onHoverWorld: { handleHoverWorld($0) },
            onHover: { viewModel.hoverID = $0 },
            onContextAction: { viewModel.handleContextAction($0) },
            onInteract: { isCanvasFocused = true },
            onNudge: { delta in viewModel.nudgeSelected(by: delta) },
            onDropLibraryItem: { id, world in viewModel.placeLibraryItem(id: id, at: world) }
        )
    }

    private func handleHoverWorld(_ world: SIMD2<Double>?) {
        pointer.world = world
        pointer.hitDescription = world.map { viewModel.pointerDescription(at: $0) }
    }
}

#Preview("Floor Plan Tab") {
    let session = ProjectSession()
    let project = session.createProject(named: "Annyeong Market")
    let layout = PreviewLayouts.annyeong()
    session.setDraft(
        ProjectDraft(name: "Annyeong Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    viewModel.selectObject(layout.objects.first { $0.kind == .booth }?.id)
    return NavigationStack {
        LayoutEditorView(viewModel: viewModel)
    }
    .preferredColorScheme(.dark)
}

#Preview("Structure Layer With Flow") {
    let session = ProjectSession()
    let project = session.createProject(named: "Preview Market")
    let layout = PreviewLayouts.smallMarket()
    session.setDraft(
        ProjectDraft(name: "Preview Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    viewModel.selectLayer(.structure)
    viewModel.showVisitorFlow = true
    viewModel.selectObject(layout.objects.first { $0.kind == .door }?.id)
    return NavigationStack {
        LayoutEditorView(viewModel: viewModel)
    }
    .preferredColorScheme(.dark)
}

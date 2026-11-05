import SwiftUI
import simd

struct LayoutEditorView: View {
    @Bindable var viewModel: LayoutEditorViewModel
    @State var canvasViewSize: SIMD2<Double> = SIMD2<Double>(960, 640)
    @State private var pointer = CanvasPointer()
    @State private var isSidePanelVisible = true
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            ToolRail(
                activeTool: viewModel.tool,
                isSidePanelOpen: isSidePanelVisible,
                onSelect: { railItem in
                    handleToolRailSelection(railItem)
                }
            )

            if isSidePanelVisible {
                LayoutEditorSidePanel(
                    viewModel: viewModel,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidePanelVisible = false
                        }
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            viewportArea

            LayoutInspectorColumn(viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 560)
        .background(Palette.background)
        .toolbar {
            editorToolbar
        }
        .focusedSceneValue(\.editorCommandActions, commandActions)
        .unsavedChangesDialog(
            isPresented: Binding(
                get: { viewModel.pendingAction != nil },
                set: { if !$0 { viewModel.cancelPendingAction() } }
            ),
            canSave: viewModel.isInspectorDraftValid,
            onSave: { viewModel.confirmPendingActionWithSave() },
            onDiscard: { viewModel.confirmPendingActionWithDiscard() },
            onCancel: { viewModel.cancelPendingAction() }
        )
        .confirmationDialog(groupDeleteDialogTitle, isPresented: isGroupDeletePending, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { viewModel.deleteGroupSelection() }
            Button("Cancel", role: .cancel) { viewModel.pendingGroupDelete = nil }
        }
    }
}

extension LayoutEditorView {
    var canvasSize: CGSize {
        CGSize(width: canvasViewSize.x, height: canvasViewSize.y)
    }

    private var canvasSnapshot: CanvasDisplaySnapshot {
        CanvasDisplaySnapshot(
            layout: viewModel.activeLayout ?? Layout(name: "", sizeM: SIMD2<Double>(20, 20)),
            legend: viewModel.legend,
            tab: viewModel.tab,
            activeLayer: viewModel.activeLayer,
            selectionID: viewModel.selectionID,
            hoverID: viewModel.hoverID,
            groupMemberIDs: viewModel.groupMemberIDs,
            hoveredGroupMemberIDs: viewModel.hoveredGroupMemberIDs,
            groupClusters: viewModel.groupClusters,
            hasUnsavedChanges: viewModel.hasUnsavedInspectorChanges,
            issues: viewModel.canvasIssueSnapshot
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
            canRotate: isRotatable,
            undo: { viewModel.undo() },
            redo: { viewModel.redo() },
            deleteSelected: { viewModel.deleteCurrentSelection() },
            duplicateSelected: { viewModel.duplicateSelected() },
            rotateSelected: { viewModel.rotateSelected() },
            zoomIn: { viewModel.zoomIn(in: canvasViewSize) },
            zoomOut: { viewModel.zoomOut(in: canvasViewSize) },
            fitToView: { viewModel.fitToView(in: canvasViewSize) }
        )
    }

    private var viewportArea: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                if viewModel.viewPreset == .plan {
                    canvasView(proxy: proxy)
                } else {
                    threeDView(proxy: proxy)
                }
            }

            if viewModel.viewPreset == .plan {
                CanvasRulers(
                    transform: viewModel.transform,
                    pointer: pointer,
                    selectionBounds: viewModel.selectionBounds
                )
            }

            CanvasOverlays(
                pointer: pointer,
                pointsPerMetre: viewModel.transform.scale,
                tool: viewModel.tool,
                message: viewModel.transientHint,
                showReadouts: viewModel.viewPreset == .plan,
                onZoomIn: {
                    if viewModel.viewPreset == .plan {
                        viewModel.zoomIn(in: canvasViewSize)
                    } else {
                        viewModel.cameraRig.zoom(byFactor: 1.25, toward: nil)
                    }
                },
                onZoomOut: {
                    if viewModel.viewPreset == .plan {
                        viewModel.zoomOut(in: canvasViewSize)
                    } else {
                        viewModel.cameraRig.zoom(byFactor: 0.8, toward: nil)
                    }
                },
                onFit: {
                    if viewModel.viewPreset == .plan {
                        viewModel.fitToView(in: canvasViewSize)
                    } else {
                        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                        viewModel.selectViewPreset(
                            viewModel.viewPreset,
                            reduceMotion: reduceMotion,
                            viewSize: canvasSize
                        )
                    }
                }
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
    private func threeDView(proxy: GeometryProxy) -> some View {
        Layout3DView(
            geometry: viewModel.sceneGeometry,
            pose: viewModel.cameraRig.pose,
            selectionOutline: viewModel.selectionOutlineBoxes,
            onOrbit: { delta in viewModel.handle3DOrbit(delta: delta) },
            onPan: { delta in viewModel.handle3DPan(delta: delta, viewHeight: Double(proxy.size.height)) },
            onZoom: { delta, isPrecise, point in
                viewModel.handle3DZoom(delta: delta, isPrecise: isPrecise, viewPoint: point, viewSize: proxy.size)
            },
            onClick: { point, size in viewModel.handle3DClick(viewPoint: point, viewSize: size) },
            onFrame: { delta in viewModel.advanceCamera(by: delta, viewSize: proxy.size) }
        )
        .onChange(of: proxy.size) { _, newSize in
            canvasViewSize = SIMD2<Double>(Double(newSize.width), Double(newSize.height))
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1")) { _ in switchPreset(.plan); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "2")) { _ in switchPreset(.threeD); return .handled }
    }

    private func switchPreset(_ preset: ViewPreset) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        viewModel.selectViewPreset(preset, reduceMotion: reduceMotion, viewSize: canvasSize)
    }

    @ViewBuilder
    private func canvasView(proxy: GeometryProxy) -> some View {
        makeLayoutCanvasView()
            .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                viewModel.deleteCurrentSelection()
                return .handled
            }
            .onKeyPress(.escape) { handleEscapeKey() }
            .onKeyPress(characters: CharacterSet(charactersIn: "1")) { _ in switchPreset(.plan); return .handled }
            .onKeyPress(characters: CharacterSet(charactersIn: "2")) { _ in switchPreset(.threeD); return .handled }
            .onKeyPress(characters: CharacterSet(charactersIn: "vV")) { _ in
                handleToolRailSelection(.select)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "wW")) { _ in
                handleToolRailSelection(.wall)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "dD")) { _ in
                openLibraryFiltered(to: .structure)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "bB")) { _ in
                handleToolRailSelection(.library)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "xX")) { _ in
                openLibraryFiltered(to: .structure)
                return .handled
            }
            .onAppear {
                canvasViewSize = SIMD2<Double>(Double(proxy.size.width), Double(proxy.size.height))
                viewModel.fitIfNeeded(in: canvasViewSize)
                viewModel.refreshDerivedState()
                isCanvasFocused = true
            }
            .onChange(of: proxy.size) { _, newSize in
                canvasViewSize = SIMD2<Double>(Double(newSize.width), Double(newSize.height))
            }
            .onChange(of: viewModel.activeLayoutID) { _, _ in
                viewModel.fitIfNeeded(in: canvasViewSize)
            }
    }

    private func handleEscapeKey() -> KeyPress.Result {
        if viewModel.tool != .select {
            viewModel.cancelActiveTool()
            return .handled
        }
        return .ignored
    }

    private func openLibraryFiltered(to category: CatalogCategory) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSidePanelVisible = true
            viewModel.inspectorPanelTab = .library
            viewModel.libraryCategory = category
        }
    }

    private func handleToolRailSelection(_ item: ToolRailItem) {
        switch item {
        case .select:
            viewModel.selectTool(.select)
        case .wall:
            viewModel.selectTool(.drawWall(itemID: "wall"))
        case .library:
            withAnimation(.easeInOut(duration: 0.2)) {
                if !isSidePanelVisible {
                    isSidePanelVisible = true
                    viewModel.inspectorPanelTab = .library
                    if let first = viewModel.cachedBoothTemplates.first {
                        viewModel.selectTool(.place(.template(first)))
                    }
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

#Preview("Flow Tab") {
    let session = ProjectSession()
    let project = session.createProject(named: "Preview Market")
    let layout = PreviewLayouts.smallMarket()
    session.setDraft(
        ProjectDraft(name: "Preview Market", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
        for: project.id
    )
    let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
    viewModel.selectTab(.flow)
    viewModel.selectObject(layout.objects.first { $0.kind == .door }?.id)
    return NavigationStack {
        LayoutEditorView(viewModel: viewModel)
    }
    .preferredColorScheme(.dark)
}

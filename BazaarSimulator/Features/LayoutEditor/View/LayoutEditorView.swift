import SwiftUI
import simd

struct LayoutEditorView: View {
    @Bindable var viewModel: LayoutEditorViewModel
    @State private var canvasViewSize: SIMD2<Double> = SIMD2<Double>(960, 640)
    @State private var pointer = CanvasPointer()
    @FocusState private var isCanvasFocused: Bool
    @State var isShowing3DView: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                LayoutCanvasView(
                    snapshot: canvasSnapshot,
                    transform: $viewModel.transform,
                    isFocused: $isCanvasFocused,
                    excludedTrailingWidth: inspectorInset,
                    onSelect: { viewModel.selectObject($0) },
                    onHover: { viewModel.hoverID = $0 },
                    onToggleSelection: { viewModel.toggleBoothInSelection($0) },
                    onDoubleClick: { id, isOptionDown in
                        viewModel.selectGroup(containing: id, bySize: isOptionDown)
                    },
                    onPointerMove: { world in
                        pointer.world = world
                        pointer.hitDescription = world.map { viewModel.pointerDescription(at: $0) }
                    },
                    onDragEnded: { id, delta, isOptionDown in
                        viewModel.finishDraggingObject(id: id, deltaWorld: delta, freeMove: isOptionDown)
                    },
                    onContextAction: { viewModel.handleContextAction($0) },
                    onInteract: { isCanvasFocused = true },
                    tool: viewModel.tool,
                    onDrawBlockedArea: { viewModel.addBlockedArea($0) },
                    onCancelTool: { viewModel.selectTool(.select) },
                    onResizeEnded: { id, placement in viewModel.finishResizingObject(id: id, to: placement) }
                )
                .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                    viewModel.deleteCurrentSelection()
                    return .handled
                }
                .onKeyPress(.upArrow, phases: .down) { press in
                    let step = press.modifiers.contains(.shift)
                        ? LayoutEditorViewModel.shiftNudgeStepM
                        : LayoutEditorViewModel.gridSnapCellM
                    viewModel.nudgeSelected(by: SIMD2<Double>(0, -step))
                    return .handled
                }
                .onKeyPress(.downArrow, phases: .down) { press in
                    let step = press.modifiers.contains(.shift)
                        ? LayoutEditorViewModel.shiftNudgeStepM
                        : LayoutEditorViewModel.gridSnapCellM
                    viewModel.nudgeSelected(by: SIMD2<Double>(0, step))
                    return .handled
                }
                .onKeyPress(.leftArrow, phases: .down) { press in
                    let step = press.modifiers.contains(.shift)
                        ? LayoutEditorViewModel.shiftNudgeStepM
                        : LayoutEditorViewModel.gridSnapCellM
                    viewModel.nudgeSelected(by: SIMD2<Double>(-step, 0))
                    return .handled
                }
                .onKeyPress(.rightArrow, phases: .down) { press in
                    let step = press.modifiers.contains(.shift)
                        ? LayoutEditorViewModel.shiftNudgeStepM
                        : LayoutEditorViewModel.gridSnapCellM
                    viewModel.nudgeSelected(by: SIMD2<Double>(step, 0))
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "rR")) { press in
                    guard press.modifiers.isEmpty else { return .ignored }
                    viewModel.rotateSelected()
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "bB")) { press in
                    guard press.modifiers.isEmpty, viewModel.tab == .floorPlan else { return .ignored }
                    viewModel.selectTool(.blockedArea)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "vV")) { press in
                    guard press.modifiers.isEmpty, viewModel.tab == .floorPlan else { return .ignored }
                    viewModel.selectTool(.select)
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

            CanvasRulers(
                transform: viewModel.transform,
                pointer: pointer,
                selectionBounds: viewModel.selectionBounds
            )

            CanvasOverlays(
                pointer: pointer,
                pointsPerMetre: viewModel.transform.scale,
                trailingInset: inspectorInset,
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

            if let selected = viewModel.selectedObject,
               viewModel.inspectorDraft != nil {
                inspectorView(for: selected)
                    .padding(.top, Spacing.l)
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, Spacing.l)
            } else if viewModel.groupSelection != nil {
                groupInspectorView()
                    .padding(.top, Spacing.l)
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, Spacing.l)
            } else if viewModel.isGroupsListVisible {
                groupsListPanel()
                    .padding(.top, Spacing.l)
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, Spacing.l)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
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
        .sheet(isPresented: $isShowing3DView) {
            if let layout = viewModel.activeLayout {
                SimulationView(layout: layout, onDismiss: { isShowing3DView = false })
            }
        }
    }

    private var inspectorInset: CGFloat {
        viewModel.isInspectorPanelVisible ? InspectorPanelMetrics.width + Spacing.l * 2 : 0
    }

    private var canvasSnapshot: CanvasDisplaySnapshot {
        CanvasDisplaySnapshot(
            layout: viewModel.activeLayout ?? Layout(name: "", sizeM: SIMD2<Double>(20, 20)),
            legend: viewModel.legend,
            tab: viewModel.tab,
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

import SwiftUI
import simd

struct LayoutEditorView: View {
    @Bindable var viewModel: LayoutEditorViewModel
    @State var canvasViewSize: SIMD2<Double> = SIMD2<Double>(960, 640)
    @State private var pointer = CanvasPointer()
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
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
                trailingInset: inspectorInset,
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
    private var inspectorInset: CGFloat {
        viewModel.isInspectorPanelVisible ? InspectorPanelMetrics.width + Spacing.l * 2 : 0
    }

    var canvasSize: CGSize {
        CGSize(width: canvasViewSize.x, height: canvasViewSize.y)
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

    @ViewBuilder
    private func threeDView(proxy: GeometryProxy) -> some View {
        Layout3DView(
            geometry: viewModel.sceneGeometry,
            pose: viewModel.cameraRig.pose,
            eye: viewModel.cameraRig.eye,
            selectionOutline: viewModel.selectionOutlineBoxes,
            onOrbit: { delta in viewModel.handle3DOrbit(delta: delta) },
            onPan: { delta in viewModel.handle3DPan(delta: delta, viewHeight: Double(proxy.size.height)) },
            onZoom: { delta, isPrecise, point in
                viewModel.handle3DZoom(delta: delta, isPrecise: isPrecise, viewPoint: point, viewSize: proxy.size)
            },
            onLook: { delta in viewModel.handle3DLook(delta: delta) },
            onWalk: { forward, right in viewModel.handle3DWalk(forward: forward, right: right) },
            onClick: { point, size in viewModel.handle3DClick(viewPoint: point, viewSize: size) },
            onFrame: { delta in viewModel.advanceCamera(by: delta, viewSize: proxy.size) }
        )
        .onChange(of: proxy.size) { _, newSize in
            canvasViewSize = SIMD2<Double>(Double(newSize.width), Double(newSize.height))
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1")) { _ in
            switchPreset(.plan)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "2")) { _ in
            switchPreset(.threeD)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "3")) { _ in
            switchPreset(.front)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "4")) { _ in
            switchPreset(.eye)
            return .handled
        }
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
            .onKeyPress(characters: CharacterSet(charactersIn: "3")) { _ in switchPreset(.front); return .handled }
            .onKeyPress(characters: CharacterSet(charactersIn: "4")) { _ in switchPreset(.eye); return .handled }
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
            viewModel.selectTool(.select)
            pointer.placementCandidate = nil
            pointer.placingSource = nil
            return .handled
        }
        return .ignored
    }

    @ViewBuilder
    private func makeLayoutCanvasView() -> some View {
        LayoutCanvasView(
            snapshot: canvasSnapshot,
            transform: $viewModel.transform,
            isFocused: $isCanvasFocused,
            excludedTrailingWidth: inspectorInset,
            onSelect: { viewModel.selectObject($0) },
            onSelectBooths: { ids, additive in viewModel.selectBooths(ids, additive: additive) },
            onHover: { viewModel.hoverID = $0 },
            onToggleSelection: { viewModel.toggleBoothInSelection($0) },
            onDoubleClick: { id, isOptionDown in
                viewModel.selectGroup(containing: id, bySize: isOptionDown)
            },
            onPointerMove: { world in handlePointerMove(world) },
            onDragEnded: { id, delta, isOptionDown in
                viewModel.finishDraggingObject(id: id, deltaWorld: delta, freeMove: isOptionDown)
            },
            onContextAction: { viewModel.handleContextAction($0) },
            onInteract: { isCanvasFocused = true },
            onNudge: { delta in viewModel.nudgeSelected(by: delta) },
            tool: viewModel.tool,
            onDrawBlockedArea: { viewModel.addBlockedArea($0) },
            onCancelTool: { viewModel.selectTool(.select) },
            onResizeEnded: { id, placement in viewModel.finishResizingObject(id: id, to: placement) },
            onDropLibraryItem: { id, world in viewModel.placeLibraryItem(id: id, at: world) },
            onCommitPlacement: { keepTool in viewModel.commitPlacement(keepTool: keepTool) },
            onCommitDoorPlacement: { keepTool, itemID in
                viewModel.commitDoorPlacement(keepTool: keepTool, itemID: itemID)
            },
            constrainDelta: { id, delta in
                viewModel.constrainDragDelta(id: id, delta: delta)
            },
            pointer: pointer,
            wallDrawing: viewModel.wallDrawing,
            onWallClick: { isShiftDown in
                if let world = pointer.world {
                    viewModel.handleWallClick(at: world, isShiftDown: isShiftDown)
                }
            },
            onWallDoubleClick: { viewModel.finishWallDrawing() },
            onWallKey: { viewModel.handleWallKey($0) },
            onWallReturn: { viewModel.handleWallReturn(currentPointer: pointer.wallCurrentPointer) },
            onWallBackspace: { viewModel.handleWallBackspace() },
            onWallFinish: { viewModel.finishWallDrawing() }
        )
    }

    private func handlePointerMove(_ world: SIMD2<Double>?) {
        pointer.world = world
        pointer.hitDescription = world.map { viewModel.pointerDescription(at: $0) }
        if case .place(let source) = viewModel.tool, let world {
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            viewModel.updatePlacementPreview(at: world, free: isOptionDown)
            pointer.placementCandidate = viewModel.placementPreview
            pointer.placingSource = source
        } else if case .placeDoor(let itemID) = viewModel.tool, let world {
            viewModel.updateDoorPlacementPreview(at: world, itemID: itemID)
            pointer.placementCandidate = viewModel.placementPreview
            pointer.placingSource = .catalog(itemID)
        } else if case .drawWall = viewModel.tool, let world {
            let isShiftDown = NSEvent.modifierFlags.contains(.shift)
            pointer.wallCurrentPointer = viewModel.handleWallPointerMove(at: world, isShiftDown: isShiftDown)
        } else {
            pointer.placementCandidate = nil
            pointer.placingSource = nil
            pointer.wallCurrentPointer = nil
        }
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

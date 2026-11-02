import SwiftUI
import simd

struct LayoutEditorView: View {
    @Bindable var viewModel: LayoutEditorViewModel
    @State private var canvasViewSize: SIMD2<Double> = SIMD2<Double>(960, 640)
    @FocusState private var isCanvasFocused: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                LayoutCanvasView(
                    snapshot: canvasSnapshot,
                    transform: $viewModel.transform,
                    onSelect: { viewModel.selectObject($0) },
                    onHover: { viewModel.hoverID = $0 },
                    onDragEnded: { id, delta, isOptionDown in
                        viewModel.finishDraggingObject(id: id, deltaWorld: delta, freeMove: isOptionDown)
                    },
                    onContextAction: { viewModel.handleContextAction($0) },
                    onInteract: { isCanvasFocused = true }
                )
                .focusable()
                .focusEffectDisabled()
                .focused($isCanvasFocused)
                .onKeyPress(keys: [.delete, .deleteForward]) { _ in
                    viewModel.deleteSelected()
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
                .onAppear {
                    canvasViewSize = SIMD2<Double>(Double(proxy.size.width), Double(proxy.size.height))
                    viewModel.refreshIssues()
                    isCanvasFocused = true
                }
                .onChange(of: proxy.size) { _, newSize in
                    canvasViewSize = SIMD2<Double>(Double(newSize.width), Double(newSize.height))
                }
            }

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
    }

    private var canvasSnapshot: CanvasDisplaySnapshot {
        CanvasDisplaySnapshot(
            layout: viewModel.activeLayout ?? Layout(name: "", sizeM: SIMD2<Double>(20, 20)),
            legend: viewModel.legend,
            tab: viewModel.tab,
            selectionID: viewModel.selectionID,
            hoverID: viewModel.hoverID,
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
            hasSelection: isMovable,
            canRotate: isRotatable,
            undo: { viewModel.undo() },
            redo: { viewModel.redo() },
            deleteSelected: { viewModel.deleteSelected() },
            duplicateSelected: { viewModel.duplicateSelected() },
            rotateSelected: { viewModel.rotateSelected() },
            zoomIn: { viewModel.zoomIn(in: canvasViewSize) },
            zoomOut: { viewModel.zoomOut(in: canvasViewSize) },
            fitToView: { viewModel.fitToView(in: canvasViewSize) }
        )
    }

    @ViewBuilder
    private func inspectorView(for selected: LayoutObject) -> some View {
        let draftBinding = Binding<InspectorDraft>(
            get: { viewModel.inspectorDraft ?? InspectorDraft(object: selected) },
            set: { viewModel.inspectorDraft = $0 }
        )

        InspectorPanel(title: viewModel.inspectorTitle) {
            switch selected.kind {
            case .booth:
                BoothInspector(
                    draft: draftBinding,
                    categories: viewModel.categoryOptions,
                    sizeRange: viewModel.sizeRangeM,
                    titleIssues: viewModel.selectedTitleIssues,
                    openSideIssues: viewModel.selectedOpenSideIssues
                )
            case .door:
                DoorInspector(
                    draft: draftBinding,
                    widthRange: viewModel.sizeRangeM,
                    advice: viewModel.currentDoorAdvice,
                    onUseAdvice: { viewModel.applyDoorAdvice() }
                )
            default:
                GenericInspector(
                    draft: draftBinding,
                    fields: .forKind(selected.kind),
                    sizeRange: viewModel.sizeRangeM,
                    titleIssues: viewModel.selectedTitleIssues
                )
            }
        } footer: {
            Button("Save Changes") {
                viewModel.saveInspectorChanges()
            }
            .buttonStyle(InspectorSaveButtonStyle())
            .disabled(!viewModel.isSaveChangesEnabled)
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
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
            SegmentedTabs(
                selection: Binding(
                    get: { viewModel.tab },
                    set: { viewModel.selectTab($0) }
                ),
                tabs: EditorTab.allCases,
                title: \.title
            )
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

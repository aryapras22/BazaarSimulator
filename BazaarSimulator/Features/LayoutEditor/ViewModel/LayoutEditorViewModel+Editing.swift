import Foundation
import simd

extension LayoutEditorViewModel {
    static let gridSnapCellM: Double = 0.25
    static let shiftNudgeStepM: Double = 1.0
    static let duplicateOffsetM: Double = 1.0

    func finishDraggingObject(id: UUID, deltaWorld: SIMD2<Double>, freeMove: Bool = false) {
        guard let layout = activeLayout,
              let before = layout.objects.first(where: { $0.id == id }),
              before.kind.isMovable else {
            return
        }
        guard simd_length(deltaWorld) > 1e-4 else { return }

        if before.kind == .door {
            if let host = DoorHosting.nearestHost(to: before.placement.center, in: layout, reach: 0.3),
               let newPlacement = DoorHosting.placement(
                   width: before.placement.sizeM.x,
                   on: host,
                   near: before.placement.center + deltaWorld
               ) {
                var after = before
                after.placement = newPlacement
                after.doorFlow?.connection = DoorHosting.connection(for: newPlacement.center, on: host, in: layout)
                guard after != before else { return }
                commitEdit(.replace(before: before, after: after), coalesceKey: "drag-\(id)")
            }
            return
        }

        var after = before
        after.placement.center += deltaWorld
        if !freeMove {
            after.placement = after.placement.snapped(toGrid: Self.gridSnapCellM)
        }
        guard after != before else { return }
        commitEdit(.replace(before: before, after: after), coalesceKey: "drag-\(id)")
    }

    func finishResizingObject(id: UUID, to placement: Placement) {
        guard let current = activeLayout?.objects.first(where: { $0.id == id }),
              current.kind.isResizable else { return }
        var updated = current
        updated.placement = placement
        commitEdit(.replace(before: current, after: updated), coalesceKey: "resize-\(id)")
        if selectionID == id {
            inspectorDraft?.widthM = placement.sizeM.x
            inspectorDraft?.lengthM = placement.sizeM.y
        }
    }

    func nudgeSelected(by deltaWorld: SIMD2<Double>) {
        guard let before = selectedObject, before.kind.isMovable, let layout = activeLayout else { return }
        let key = "nudge-\(before.id)"
        if before.kind == .door {
            if let host = DoorHosting.nearestHost(to: before.placement.center, in: layout, reach: 0.3),
               let newPlacement = DoorHosting.placement(
                   width: before.placement.sizeM.x,
                   on: host,
                   near: before.placement.center + deltaWorld
               ) {
                var after = before
                after.placement = newPlacement
                guard after != before else { return }
                withSingleRefresh {
                    commitEdit(.replace(before: before, after: after), coalesceKey: key)
                    applySelection(after.id)
                }
            }
            return
        }
        var after = before
        after.placement.center += deltaWorld
        commitEdit(.replace(before: before, after: after), coalesceKey: key)
    }

    func rotateSelected() {
        guard let before = selectedObject, before.kind.isRotatable else { return }
        var after = before
        after.placement = before.placement.rotatedQuarterTurns(1)
        withSingleRefresh {
            commitEdit(.replace(before: before, after: after))
            inspectorDraft?.rotationDegrees = after.placement.rotationDegrees
        }
    }

    func deleteSelected() {
        guard let layout = activeLayout,
              let selectionID,
              let index = layout.objects.firstIndex(where: { $0.id == selectionID }) else {
            return
        }
        let target = layout.objects[index]
        guard target.kind.isMovable else { return }
        withSingleRefresh {
            commitEdit(.delete(target, index: index))
            self.selectionID = nil
            inspectorDraft = nil
        }
    }

    func duplicateSelected() {
        guard let layout = activeLayout,
              let selected = selectedObject,
              selected.kind.isMovable else {
            return
        }
        var copy = selected
        copy.id = UUID()
        let prefix = BoothGrouping.namePrefix(of: selected.label)
        copy.label = selected.kind == .booth
            ? LayoutObjectNaming.nextPrefixedLabel(prefix: prefix, kind: .booth, in: layout)
            : nextLabel(for: selected.kind, in: layout)
        copy.placement.center += SIMD2<Double>(Self.duplicateOffsetM, Self.duplicateOffsetM)
        withSingleRefresh {
            commitEdit(.insert(copy, index: layout.objects.count))
            applySelection(copy.id)
        }
    }

    func resetOpenSidesForSelected() {
        guard let layout = activeLayout,
              let before = selectedObject,
              before.kind == .booth else {
            return
        }
        var after = before
        after.openSides = OpenSideInference.defaultSide(for: before, in: layout)
        withSingleRefresh {
            if after != before {
                commitEdit(.replace(before: before, after: after))
            }
            inspectorDraft?.openSides = after.openSides
        }
    }

    func addObject(kind: LayoutObjectKind, at worldPoint: SIMD2<Double>) {
        guard let layout = activeLayout else { return }
        let defaultSize: SIMD2<Double>
        switch kind {
        case .booth: defaultSize = SIMD2<Double>(2.0, 2.0)
        case .closedArea: defaultSize = SIMD2<Double>(4.0, 4.0)
        default: defaultSize = SIMD2<Double>(2.0, 2.0)
        }

        let placement = Placement(center: worldPoint, sizeM: defaultSize)
            .snapped(toGrid: Self.gridSnapCellM)
        var newObject = LayoutObject(
            kind: kind,
            label: nextLabel(for: kind, in: layout),
            placement: placement
        )
        if kind == .booth {
            newObject.openSides = OpenSideInference.defaultSide(for: newObject, in: layout)
        }
        withSingleRefresh {
            commitEdit(.insert(newObject, index: layout.objects.count))
            applySelection(newObject.id)
        }
    }

    func selectTool(_ newTool: EditorTool) {
        guard newTool != tool else { return }
        sealHistory()
        tool = newTool
        if case .drawWall(let itemID) = newTool {
            selectedWallItemID = itemID
        } else if case .room(let itemID) = newTool {
            selectedWallItemID = itemID
        }
        placementRotationDegrees = 0
        placementPreview = nil
        wallDrawing = nil
        dragState = CanvasDragState()
        activeToolHandler = nil
        if newTool == .blockedArea || newTool != .select {
            applySelection(nil)
        }
    }

    func addBlockedArea(_ placement: Placement) {
        guard let layout = activeLayout else { return }
        let area = LayoutObject(
            kind: .closedArea,
            label: nextLabel(for: .closedArea, in: layout),
            placement: placement
        )
        withSingleRefresh {
            commitEdit(.insert(area, index: layout.objects.count))
            applySelection(area.id)
            tool = .select
        }
    }

    func undo() {
        guard let edit = currentHistory.undo() else { return }
        applyHistoryEdit(edit)
    }

    func redo() {
        guard let edit = currentHistory.redo() else { return }
        applyHistoryEdit(edit)
    }

    func zoomIn(in viewSize: SIMD2<Double>) {
        transform = transform.zoomed(by: 1.25, around: viewSize / 2.0)
    }

    func zoomOut(in viewSize: SIMD2<Double>) {
        transform = transform.zoomed(by: 0.8, around: viewSize / 2.0)
    }

    func fitToView(in viewSize: SIMD2<Double>) {
        guard let layout = activeLayout else { return }
        transform = CanvasTransform.fitting(layoutSize: layout.sizeM, in: viewSize)
        autoFitTransform = transform
        hasFittedTransform = true
    }

    /// The canvas size is not final when the editor first appears, so the first fit can be off.
    /// Fitting again on resize is safe only while the user has not zoomed or panned since the last fit.
    func refitIfUntouched(in viewSize: SIMD2<Double>) {
        guard hasFittedTransform, transform == autoFitTransform else { return }
        fitToView(in: viewSize)
    }

    func fitIfNeeded(in viewSize: SIMD2<Double>) {
        guard !hasFittedTransform else { return }
        fitToView(in: viewSize)
    }

    func handleContextAction(_ action: CanvasContextAction) {
        if handleGroupContextAction(action) { return }
        switch action {
        case .rotate(let id):
            guard prepareContextTarget(id) else { return }
            rotateSelected()
        case .duplicate(let id):
            guard prepareContextTarget(id) else { return }
            duplicateSelected()
        case .resetOpenSides(let id):
            guard prepareContextTarget(id) else { return }
            resetOpenSidesForSelected()
        case .delete(let id):
            guard prepareContextTarget(id) else { return }
            deleteSelected()
        case let .addObject(kind, worldPoint):
            addObject(kind: kind, at: worldPoint)
        }
    }

    private func handleGroupContextAction(_ action: CanvasContextAction) -> Bool {
        switch action {
        case .resetOpenSides(let id) where groupMemberIDs.contains(id):
            resetOpenSidesForGroup()
            return true
        case .delete(let id) where groupMemberIDs.contains(id):
            deleteCurrentSelection()
            return true
        default:
            return false
        }
    }

    private func prepareContextTarget(_ id: UUID) -> Bool {
        if selectionID != id {
            selectObject(id)
        }
        return selectionID == id
    }

    func nextLabel(for kind: LayoutObjectKind, in layout: Layout) -> String {
        LayoutObjectNaming.nextLabel(for: kind, in: layout)
    }
}

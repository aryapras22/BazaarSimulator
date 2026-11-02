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

        var after = before
        after.placement.center += deltaWorld
        if !freeMove {
            after.placement = after.placement.snapped(toGrid: Self.gridSnapCellM)
        }
        guard after != before else { return }
        commitEdit(.replace(before: before, after: after))
    }

    func nudgeSelected(by deltaWorld: SIMD2<Double>) {
        guard let before = selectedObject, before.kind.isMovable else { return }
        var after = before
        after.placement.center += deltaWorld
        commitEdit(.replace(before: before, after: after))
    }

    func rotateSelected() {
        guard let before = selectedObject, before.kind.isRotatable else { return }
        var after = before
        after.placement = before.placement.rotatedQuarterTurns(1)
        commitEdit(.replace(before: before, after: after))
        inspectorDraft?.rotationDegrees = after.placement.rotationDegrees
    }

    func deleteSelected() {
        guard let layout = activeLayout,
              let selectionID,
              let index = layout.objects.firstIndex(where: { $0.id == selectionID }) else {
            return
        }
        let target = layout.objects[index]
        guard target.kind.isMovable else { return }
        commitEdit(.delete(target, index: index))
        self.selectionID = nil
        inspectorDraft = nil
    }

    func duplicateSelected() {
        guard let layout = activeLayout,
              let selected = selectedObject,
              selected.kind.isMovable else {
            return
        }
        var copy = selected
        copy.id = UUID()
        copy.label = nextLabel(for: selected.kind, in: layout)
        copy.placement.center += SIMD2<Double>(Self.duplicateOffsetM, Self.duplicateOffsetM)
        commitEdit(.insert(copy, index: layout.objects.count))
        applySelection(copy.id)
    }

    func resetOpenSidesForSelected() {
        guard let layout = activeLayout,
              let before = selectedObject,
              before.kind == .booth else {
            return
        }
        var after = before
        after.openSides = OpenSideInference.infer(for: before, in: layout)
        if after != before {
            commitEdit(.replace(before: before, after: after))
        }
        inspectorDraft?.openSides = after.openSides
    }

    func addObject(kind: LayoutObjectKind, at worldPoint: SIMD2<Double>) {
        guard kind.canBeAdded, let layout = activeLayout else { return }
        let defaultSize: SIMD2<Double>
        switch kind {
        case .booth: defaultSize = SIMD2<Double>(2.0, 2.0)
        case .table: defaultSize = SIMD2<Double>(1.0, 1.0)
        case .fixture: defaultSize = SIMD2<Double>(2.0, 1.5)
        case .rail: defaultSize = SIMD2<Double>(2.0, 0.25)
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
            newObject.openSides = OpenSideInference.infer(for: newObject, in: layout)
        }
        commitEdit(.insert(newObject, index: layout.objects.count))
        applySelection(newObject.id)
    }

    func undo() {
        if hasUnsavedInspectorChanges {
            pendingAction = .performUndo
            return
        }
        guard let edit = currentHistory.undo() else { return }
        applyHistoryEdit(edit)
    }

    func redo() {
        if hasUnsavedInspectorChanges {
            pendingAction = .performRedo
            return
        }
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
    }

    func handleContextAction(_ action: CanvasContextAction) {
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

    private func prepareContextTarget(_ id: UUID) -> Bool {
        if selectionID != id {
            selectObject(id)
        }
        return pendingAction == nil && selectionID == id
    }

    private func nextLabel(for kind: LayoutObjectKind, in layout: Layout) -> String {
        switch kind {
        case .booth:
            return nextPrefixedLabel(prefix: "B", kind: kind, in: layout)
        case .table:
            return nextPrefixedLabel(prefix: "T", kind: kind, in: layout)
        case .fixture:
            return nextPrefixedLabel(prefix: "Fixture ", kind: kind, in: layout)
        case .rail:
            return "Rail"
        default:
            let existingCount = layout.objects.filter { $0.kind == kind }.count + 1
            return "\(kind.displayName) \(existingCount)"
        }
    }

    private func nextPrefixedLabel(prefix: String, kind: LayoutObjectKind, in layout: Layout) -> String {
        let highest = layout.objects
            .filter { $0.kind == kind && $0.label.hasPrefix(prefix) }
            .compactMap { Int($0.label.dropFirst(prefix.count)) }
            .max() ?? 0
        return "\(prefix)\(highest + 1)"
    }
}

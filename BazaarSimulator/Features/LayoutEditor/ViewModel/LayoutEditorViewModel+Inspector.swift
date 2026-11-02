import Foundation
import simd

extension LayoutEditorViewModel {
    var categoryOptions: [CategoryOption] {
        var options = [CategoryOption(id: nil, name: "Unassigned", color: nil)]
        for entry in legend.entries {
            options.append(CategoryOption(id: entry.id, name: entry.name, color: entry.color))
        }
        return options
    }

    var inspectorTitle: String {
        guard let selected = selectedObject, let layout = activeLayout else { return "" }
        let draftLabel = inspectorDraft?.label ?? selected.label
        switch selected.kind {
        case .booth:
            return "Booth \(BoothLabelFormatter.display(draftLabel))"
        case .table:
            return "Table \(draftLabel)"
        case .door:
            return DoorLabelFormatter.displayTitle(for: selected, in: layout)
        case .fixture, .audienceArea:
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? selected.kind.displayName : trimmed
        case .stage:
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Stage" : trimmed
        case .wall, .rail, .block, .pillar, .closedArea:
            return selected.kind.displayName
        }
    }

    var sizeRangeM: ClosedRange<Double> {
        guard let selected = selectedObject else { return 0.5...100.0 }
        let minVal = selected.kind.minimumDimensionM
        if selected.kind == .door {
            return minVal...maxDoorWidthM(for: selected)
        }
        let maxLayoutDim = max(activeLayout?.sizeM.x ?? 100.0, activeLayout?.sizeM.y ?? 100.0)
        return minVal...max(minVal, maxLayoutDim)
    }

    var isInspectorDraftValid: Bool {
        guard let draft = inspectorDraft, let selected = selectedObject else { return false }
        let range = sizeRangeM
        guard range.contains(draft.widthM) else { return false }
        if selected.kind != .pillar && selected.kind != .door {
            guard range.contains(draft.lengthM) else { return false }
        }
        let allowedRotations = [0, 90, 180, 270]
        if selected.kind.isRotatable && !allowedRotations.contains(draft.rotationDegrees) {
            return false
        }
        return true
    }

    var isSaveChangesEnabled: Bool {
        hasUnsavedInspectorChanges && isInspectorDraftValid
    }

    var layoutWithInspectorDraft: Layout? {
        guard var layout = activeLayout else { return nil }
        if let selected = selectedObject,
           let draft = inspectorDraft,
           let index = layout.objects.firstIndex(where: { $0.id == selected.id }) {
            layout.objects[index] = draft.applied(to: selected)
        }
        return layout
    }

    func saveInspectorChanges() {
        guard isSaveChangesEnabled,
              let selected = selectedObject,
              let draft = inspectorDraft else {
            return
        }
        let updated = draft.applied(to: selected)
        commitEdit(.replace(before: selected, after: updated))
        if let refreshed = selectedObject {
            inspectorDraft = InspectorDraft(object: refreshed)
        }
    }

    func discardInspectorChanges() {
        if let selected = selectedObject {
            inspectorDraft = InspectorDraft(object: selected)
        } else {
            inspectorDraft = nil
        }
    }

    func confirmPendingActionWithSave() {
        guard isInspectorDraftValid else {
            pendingAction = nil
            return
        }
        saveInspectorChanges()
        executePendingAction()
    }

    func confirmPendingActionWithDiscard() {
        discardInspectorChanges()
        executePendingAction()
    }

    func cancelPendingAction() {
        pendingAction = nil
    }

    func toggleScreenOpenSide(_ screenSide: OpenSides) {
        guard var draft = inspectorDraft else { return }
        let localSide = OpenSides.localSide(
            forScreenSide: screenSide,
            rotationDegrees: draft.rotationDegrees
        )
        if draft.kind.allowsMultipleOpenSides {
            if draft.openSides.contains(localSide) {
                draft.openSides.remove(localSide)
            } else {
                draft.openSides.insert(localSide)
            }
        } else {
            draft.openSides = localSide
        }
        inspectorDraft = draft
    }

    private func executePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .selectObject(let objectID):
            applySelection(objectID)
        case .switchTab(let newTab):
            tab = newTab
            applySelection(nil)
        case .switchLayout(let layoutID):
            session.setActiveLayoutID(layoutID, for: projectID)
            applySelection(nil)
        case .navigateBack:
            onBack()
        case .performUndo:
            if let edit = currentHistory.undo() {
                applyHistoryEdit(edit)
            }
        }
    }

    private func maxDoorWidthM(for door: LayoutObject) -> Double {
        guard let layout = activeLayout else { return 20.0 }
        if door.doorFlow?.connection == .hallToLobby,
           let wall = layout.objects.first(where: { $0.kind == .wall && $0.label == "Lobby wall" }) {
            return max(door.kind.minimumDimensionM, wall.placement.sizeM.x)
        }
        return max(door.kind.minimumDimensionM, max(layout.sizeM.x, layout.sizeM.y))
    }
}

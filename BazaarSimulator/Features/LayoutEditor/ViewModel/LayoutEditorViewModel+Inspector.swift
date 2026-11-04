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
        case .fixture, .audienceArea, .closedArea:
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? selected.kind.displayName : trimmed
        case .stage:
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Stage" : trimmed
        case .wall, .rail, .block, .pillar:
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
        if groupSelection != nil { return isGroupDraftValid }
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
        let heightKinds: Set<LayoutObjectKind> = [.wall, .rail, .block, .booth, .stage, .fixture]
        if heightKinds.contains(selected.kind) && !(0.1...10.0).contains(draft.heightM) {
            return false
        }
        return !issues.contains {
            $0.severity == .error && $0.objectIDs.contains(selected.id)
        }
    }

    var canvasIssueSnapshot: CanvasIssueSnapshot {
        var warningIDs: Set<UUID> = []
        var blockedByBooth: [UUID: OpenSides] = [:]
        for issue in issues where issue.severity == .warning {
            switch issue.kind {
            case .overlappingObjects, .outsideFloor:
                warningIDs.formUnion(issue.objectIDs)
            case .blockedOpenSide(let side):
                for id in issue.objectIDs {
                    var sides = blockedByBooth[id] ?? []
                    sides.insert(side)
                    blockedByBooth[id] = sides
                }
            case .noOpenSides, .missingHallDoorEntry, .missingHallDoorExit, .belowMinimumSize:
                break
            }
        }
        return CanvasIssueSnapshot(warningObjectIDs: warningIDs, blockedSidesByBoothID: blockedByBooth)
    }

    var selectedTitleIssues: [String] {
        guard let selectedID = selectionID else { return [] }
        return issues.compactMap { issue in
            guard issue.objectIDs.contains(selectedID) else { return nil }
            switch issue.kind {
            case .overlappingObjects, .outsideFloor:
                return issue.message
            default:
                return nil
            }
        }
    }

    var selectedOpenSideIssues: [String] {
        guard let selectedID = selectionID else { return [] }
        return issues.compactMap { issue in
            guard issue.objectIDs.contains(selectedID) else { return nil }
            switch issue.kind {
            case .blockedOpenSide, .noOpenSides:
                return issue.message
            default:
                return nil
            }
        }
    }

    var flowBannerIssues: [String] {
        guard tab == .flow else { return [] }
        return issues.compactMap { issue in
            switch issue.kind {
            case .missingHallDoorEntry, .missingHallDoorExit:
                return issue.message
            default:
                return nil
            }
        }
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
        if groupSelection != nil, let draft = groupDraft {
            let memberIDs = Set(draft.memberIDs)
            for index in layout.objects.indices where memberIDs.contains(layout.objects[index].id) {
                layout.objects[index] = draft.applied(to: layout.objects[index])
            }
        }
        return layout
    }

    var currentDoorAdvice: DoorAdviceDisplay? {
        guard let selected = selectedObject,
              selected.kind == .door,
              let draft = inspectorDraft,
              let previewLayout = layoutWithInspectorDraft else {
            return nil
        }
        let previewDoor = draft.applied(to: selected)
        guard let advice = DoorFlowAdvisor.advice(for: previewDoor, in: previewLayout) else {
            return nil
        }
        return DoorAdviceDisplay(
            message: advice.message,
            actionTitle: advice.actionTitle,
            suggestedDirection: advice.suggestedDirection
        )
    }

    func applyDoorAdvice() {
        guard let advice = currentDoorAdvice else { return }
        inspectorDraft?.doorDirection = advice.suggestedDirection
    }

    func saveInspectorChanges() {
        if groupSelection != nil {
            saveGroupChanges()
            return
        }
        guard isSaveChangesEnabled,
              let selected = selectedObject,
              let draft = inspectorDraft else {
            return
        }
        withSingleRefresh {
            let updated = draft.applied(to: selected)
            commitEdit(.replace(before: selected, after: updated))
            if let refreshed = selectedObject {
                inspectorDraft = InspectorDraft(object: refreshed)
            }
        }
    }

    func discardInspectorChanges() {
        if let draft = groupDraft, groupSelection != nil {
            groupDraft = GroupInspectorDraft(memberIDs: draft.memberIDs)
        } else if let selected = selectedObject {
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
        withSingleRefresh {
            saveInspectorChanges()
            executePendingAction()
        }
    }

    func confirmPendingActionWithDiscard() {
        withSingleRefresh {
            discardInspectorChanges()
            executePendingAction()
        }
    }

    func cancelPendingAction() {
        pendingAction = nil
    }

    private func maxDoorWidthM(for door: LayoutObject) -> Double {
        guard let layout = activeLayout else { return 20.0 }
        if door.doorFlow?.connection == .hallToLobby,
           let wall = layout.objects.first(where: {
               $0.kind == .wall && LayoutGeometry.contains($0.placement, point: door.placement.center, tolerance: 0.5)
           }) {
            return max(door.kind.minimumDimensionM, wall.placement.sizeM.x)
        }
        return max(door.kind.minimumDimensionM, max(layout.sizeM.x, layout.sizeM.y))
    }
}

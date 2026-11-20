import Foundation
import simd

extension LayoutEditorViewModel {
    var categoryOptions: [CategoryOption] {
        CategoryOption.boothOptions
    }

    var inspectorTitle: String {
        guard let selected = selectedObject, let layout = activeLayout else { return "" }
        let kind = inspectorDraft?.kind ?? selected.kind
        let draftLabel = inspectorDraft?.label ?? selected.label
        switch kind {
        case .booth:
            return "Booth \(BoothLabelFormatter.display(draftLabel))"
        case .door:
            return DoorLabelFormatter.displayTitle(for: selected, in: layout)
        case .block where selected.isColumn:
            return "Column"
        case .closedArea, .table, .seating, .block, .entertainment:
            let trimmed = draftLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? kind.displayName : trimmed
        case .wall:
            return WallLabelFormatter.displayTitle(for: selected, in: layout)
        }
    }

    /// The name the pencil next to the title edits. A booth is titled "Booth" and its label, so only the label is
    /// edited. Every other title is the name itself.
    var inspectorEditableName: String {
        guard let selected = selectedObject else { return "" }
        let kind = inspectorDraft?.kind ?? selected.kind
        if kind == .booth { return inspectorDraft?.label ?? selected.label }
        return inspectorTitle
    }

    /// Renames the selected element. A name equal to the one it would get anyway is stored as no name, so the
    /// element keeps following its place, such as the compass side of a door.
    func renameSelected(to name: String) {
        guard let selected = selectedObject, var draft = inspectorDraft else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let automatic = draft.kind == .booth ? "" : automaticTitle(for: selected, kind: draft.kind)
        draft.label = trimmed == automatic ? "" : trimmed
        updateInspectorDraft(draft)
    }

    private func automaticTitle(for object: LayoutObject, kind: LayoutObjectKind) -> String {
        guard let layout = activeLayout else { return "" }
        switch kind {
        case .door: return "Door \(DoorLabelFormatter.compassName(for: object, in: layout))"
        case .wall: return "Wall \(WallLabelFormatter.sideName(for: object, in: layout))"
        default: return kind.displayName
        }
    }

    /// Finishes editing the selected element. Its changes are already in the layout and can be undone, so this
    /// closes the panel on it, after checking that what was entered is valid.
    func saveChanges() {
        guard groupSelection != nil || isInspectorDraftValid else { return }
        selectObject(nil)
    }

    var sizeRangeM: ClosedRange<Double> {
        guard let selected = selectedObject else { return 0.5...100.0 }
        let kind = inspectorDraft?.kind ?? selected.kind
        let minVal = kind.minimumDimensionM
        if kind == .door {
            return minVal...maxDoorWidthM(for: selected)
        }
        let maxLayoutDim = max(activeLayout?.sizeM.x ?? 100.0, activeLayout?.sizeM.y ?? 100.0)
        return minVal...max(minVal, maxLayoutDim)
    }

    var isInspectorDraftValid: Bool {
        if groupSelection != nil { return isGroupDraftValid }
        guard let draft = inspectorDraft, let selected = selectedObject else { return false }
        let kind = draft.kind
        let range = sizeRangeM
        guard range.contains(draft.widthM) else { return false }
        if kind != .door {
            guard range.contains(draft.lengthM) else { return false }
        }
        let rotationStep = kind.rotationStepDegrees
        if kind.isRotatable && draft.rotationDegrees % rotationStep != 0 {
            return false
        }
        let heightKinds: Set<LayoutObjectKind> = [.wall, .block, .booth]
        if heightKinds.contains(kind) && !(0.1...10.0).contains(draft.heightM) {
            return false
        }
        if kind.hasAttractiveness && !AttractivenessField.isValid(draft.attractiveness) {
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

    func focusIssue(_ issue: LayoutIssue, in viewSize: SIMD2<Double>) {
        guard let layout = activeLayout,
              let target = issue.objectIDs.lazy.compactMap({ id in layout.objects.first { $0.id == id } }).first else {
            return
        }
        if target.kind.layer != activeLayer {
            selectLayer(target.kind.layer)
        }
        selectObject(target.id)
        transform = transform.centered(on: target.placement.center, in: viewSize)
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
        guard showVisitorFlow || activeLayer == .structure else { return [] }
        return issues.compactMap { issue in
            switch issue.kind {
            case .missingHallDoorEntry, .missingHallDoorExit:
                return issue.message
            default:
                return nil
            }
        }
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
        guard let advice = currentDoorAdvice, var draft = inspectorDraft else { return }
        draft.doorDirection = advice.suggestedDirection
        updateInspectorDraft(draft)
    }

    func updateInspectorDraft(_ draft: InspectorDraft) {
        inspectorDraft = draft
        applyInspectorDraft()
    }

    private func applyInspectorDraft() {
        guard isInspectorDraftValid,
              let selected = selectedObject,
              let draft = inspectorDraft else {
            return
        }
        let updated = draft.applied(to: selected)
        if selected.kind == .wall,
           let layout = activeLayout,
           abs(draft.widthM - selected.placement.sizeM.x) > 1e-4 {
            withSingleRefresh {
                let edit = WallEditing.setWallLength(
                    wall: selected,
                    newLength: draft.widthM,
                    anchor: .start,
                    in: layout,
                    graph: WallGraph(layout: layout)
                )
                commitEdit(edit)
                if let lengthened = activeLayout?.objects.first(where: { $0.id == selected.id }) {
                    let final = draft.applied(to: lengthened)
                    if final != lengthened {
                        commitEdit(.replace(before: lengthened, after: final))
                    }
                    inspectorDraft = InspectorDraft(object: final)
                }
            }
        } else if updated != selected {
            commitEdit(.replace(before: selected, after: updated), coalesceKey: "inspector-\(selected.id)")
        }
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

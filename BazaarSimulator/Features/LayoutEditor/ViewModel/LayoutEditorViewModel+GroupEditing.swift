import Foundation
import simd

extension LayoutEditorViewModel {
    private static let allowedRotations = [0, 90, 180, 270]

    var isInspectorPanelVisible: Bool {
        (selectedObject != nil && inspectorDraft != nil) || groupSelection != nil || isGroupsListVisible
    }

    var groupSizeRangeM: ClosedRange<Double> {
        let minimum = LayoutObjectKind.booth.minimumDimensionM
        let maximum = max(activeLayout?.sizeM.x ?? 100.0, activeLayout?.sizeM.y ?? 100.0)
        return minimum...max(minimum, maximum)
    }

    var isGroupDraftValid: Bool {
        guard let draft = groupDraft else { return false }
        let range = groupSizeRangeM
        if case .set(let width) = draft.widthM, !range.contains(width) { return false }
        if case .set(let length) = draft.lengthM, !range.contains(length) { return false }
        if case .set(let degrees) = draft.rotationDegrees, !Self.allowedRotations.contains(degrees) { return false }
        let memberIDs = Set(draft.memberIDs)
        return !issues.contains { $0.severity == .error && !memberIDs.isDisjoint(with: $0.objectIDs) }
    }

    var groupInspectorDisplay: GroupInspectorDisplay {
        let members = selectedGroupMembers.map { groupDraft?.applied(to: $0) ?? $0 }
        return GroupInspectorDisplay(
            category: MixedValue(members.map(\.categoryID)),
            width: MixedValue(members.map { DimensionInput.rounded($0.placement.sizeM.x) }),
            length: MixedValue(members.map { DimensionInput.rounded($0.placement.sizeM.y) }),
            rotation: MixedValue(members.map(\.placement.rotationDegrees)),
            warningSummary: groupWarningSummary,
            memberCount: members.count
        )
    }

    var groupWarningSummary: String? {
        let memberIDs = Set(selectedGroupMembers.map(\.id))
        let warned = issues
            .filter { $0.severity == .warning }
            .reduce(into: Set<UUID>()) { $0.formUnion($1.objectIDs) }
            .intersection(memberIDs)
        switch warned.count {
        case 0: return nil
        case 1: return "1 booth has a warning"
        default: return "\(warned.count) booths have warnings"
        }
    }

    func saveGroupChanges() {
        guard isSaveChangesEnabled, let draft = groupDraft else { return }
        let edits = selectedGroupMembers.compactMap { member -> LayoutEdit? in
            let updated = draft.applied(to: member)
            return updated == member ? nil : .replace(before: member, after: updated)
        }
        withSingleRefresh {
            if !edits.isEmpty { commitEdit(.batch(edits)) }
            groupDraft = GroupInspectorDraft(memberIDs: draft.memberIDs)
        }
    }

    func resetOpenSidesForGroup() {
        guard let layout = activeLayout else { return }
        let edits = selectedGroupMembers.compactMap { member -> LayoutEdit? in
            var updated = member
            updated.openSides = OpenSideInference.defaultSide(for: member, in: layout)
            return updated == member ? nil : .replace(before: member, after: updated)
        }
        guard !edits.isEmpty else { return }
        commitEdit(.batch(edits))
    }

    func requestDeleteGroup() {
        guard let groupSelection else { return }
        pendingGroupDelete = groupSelection.memberIDs.count
    }

    func deleteGroupSelection() {
        pendingGroupDelete = nil
        guard let layout = activeLayout, let groupSelection else { return }
        let doomed = layout.objects.enumerated()
            .filter { groupSelection.memberIDs.contains($0.element.id) }
            .reversed()
        guard !doomed.isEmpty else { return }
        withSingleRefresh {
            commitEdit(.batch(doomed.map { .delete($0.element, index: $0.offset) }))
            applySelection(nil)
        }
    }

    func deleteCurrentSelection() {
        if groupSelection != nil {
            requestDeleteGroup()
        } else {
            deleteSelected()
        }
    }
}

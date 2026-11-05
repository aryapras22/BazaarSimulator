import Foundation
import simd

extension LayoutEditorViewModel {
    var selectedGroupMembers: [LayoutObject] {
        guard let groupSelection, let activeLayout else { return [] }
        return activeLayout.objects.filter { groupSelection.memberIDs.contains($0.id) }
    }

    var groupSelectionTitle: String {
        guard let groupSelection else { return "" }
        let count = "\(groupSelection.memberIDs.count) booths"
        switch groupSelection.kind {
        case .group(.name(let prefix)): return "Group \(prefix) · \(count)"
        case .group(.size(let key)): return "Size \(key.title) · \(count)"
        case .custom: return count
        }
    }

    var groupMemberIDs: Set<UUID> {
        groupSelection?.memberIDs ?? []
    }

    var hoveredGroupMemberIDs: Set<UUID> {
        guard let hoveredGroup, let group = boothGroup(hoveredGroup) else { return [] }
        return Set(group.memberIDs)
    }

    func boothGroupActions(for booth: LayoutObject) -> BoothGroupActions? {
        guard booth.kind == .booth else { return nil }
        let nameKind = BoothGrouping.nameKind(for: booth)
        let sizeKind = BoothGrouping.sizeKind(for: booth)
        guard let nameGroup = boothGroup(nameKind), let sizeGroup = boothGroup(sizeKind) else { return nil }
        return BoothGroupActions(
            nameTitle: "Select group \(nameGroup.title) · \(nameGroup.memberIDs.count)",
            sizeTitle: "Select size \(sizeGroup.title) · \(sizeGroup.memberIDs.count)",
            onSelectName: { [weak self] in self?.selectGroup(nameKind) },
            onSelectSize: { [weak self] in self?.selectGroup(sizeKind) }
        )
    }

    func boothGroup(_ kind: BoothGroupKind) -> BoothGroup? {
        switch kind {
        case .name: return nameGroups.first { $0.kind == kind }
        case .size: return sizeGroups.first { $0.kind == kind }
        }
    }

    func selectGroup(_ kind: BoothGroupKind) {
        guard activeLayer == .booths, boothGroup(kind) != nil else { return }
        if hasUnsavedInspectorChanges {
            pendingAction = .selectGroup(kind)
            return
        }
        performSelectGroup(kind)
    }

    func selectGroup(containing boothID: UUID, bySize: Bool) {
        guard let booth = activeLayout?.objects.first(where: { $0.id == boothID && $0.kind == .booth }) else { return }
        selectGroup(bySize ? BoothGrouping.sizeKind(for: booth) : BoothGrouping.nameKind(for: booth))
    }

    func toggleBoothInSelection(_ boothID: UUID) {
        guard activeLayer == .booths,
              activeLayout?.objects.contains(where: { $0.id == boothID && $0.kind == .booth }) == true else {
            return
        }
        if hasUnsavedInspectorChanges {
            pendingAction = .toggleBooth(boothID)
            return
        }
        performToggleBooth(boothID)
    }

    func selectBooths(_ ids: Set<UUID>, additive: Bool = false) {
        guard activeLayer == .booths, let layout = activeLayout else { return }
        let boothIDs = ids.filter { id in
            layout.objects.contains(where: { $0.id == id && $0.kind == .booth })
        }
        if hasUnsavedInspectorChanges {
            pendingAction = .selectBooths(ids: boothIDs, additive: additive)
            return
        }
        performSelectBooths(boothIDs, additive: additive)
    }

    func executeGroupAction(_ action: PendingNavigationAction) {
        switch action {
        case .selectGroup(let kind): performSelectGroup(kind)
        case .toggleBooth(let boothID): performToggleBooth(boothID)
        case .selectBooths(let ids, let additive): performSelectBooths(ids, additive: additive)
        default: break
        }
    }

    private func performSelectBooths(_ ids: Set<UUID>, additive: Bool) {
        var members = ids
        if additive {
            var current = groupSelection?.memberIDs ?? []
            if groupSelection == nil, let selectedObject, selectedObject.kind == .booth {
                current = [selectedObject.id]
            }
            members = current.union(ids)
        }
        applyMemberSelection(members, kind: .custom)
    }

    private func performSelectGroup(_ kind: BoothGroupKind) {
        guard let group = boothGroup(kind) else { return }
        applyMemberSelection(Set(group.memberIDs), kind: .group(kind))
    }

    private func performToggleBooth(_ boothID: UUID) {
        var members = groupSelection?.memberIDs ?? []
        if groupSelection == nil, let selectedObject, selectedObject.kind == .booth {
            members = [selectedObject.id]
        }
        if members.contains(boothID) {
            members.remove(boothID)
        } else {
            members.insert(boothID)
        }
        applyMemberSelection(members, kind: .custom)
    }

    private func selectedMembers(of ids: Set<UUID>) -> [LayoutObject] {
        activeLayout?.objects.filter { ids.contains($0.id) } ?? []
    }

    func applyGroupSelection(_ selection: GroupSelection?) {
        if selection != groupSelection || selectionID != nil {
            sealHistory()
        }
        hoveredGroup = nil
        selectionID = nil
        inspectorDraft = nil
        groupSelection = selection
        groupDraft = selection.map { _ in GroupInspectorDraft(memberIDs: selectedGroupMembers.map(\.id)) }
    }

    func applyMemberSelection(_ members: Set<UUID>, kind: GroupSelection.Kind) {
        switch members.count {
        case 0: applySelection(nil)
        case 1: applySelection(members.first)
        default:
            let objects = selectedMembers(of: members)
            applyGroupSelection(
                GroupSelection(kind: kind, memberIDs: members, clusters: BoothGrouping.clusters(of: objects))
            )
        }
    }
}

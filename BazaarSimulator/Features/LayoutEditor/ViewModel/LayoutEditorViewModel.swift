import Foundation
import Observation
import simd

struct CategoryOption: Identifiable, Hashable, Sendable {
    var id: UUID?
    var name: String
    var color: LegendColor?
}

struct DoorAdviceDisplay: Hashable, Sendable {
    let message: String
    let actionTitle: String
    let suggestedDirection: DoorDirection
}

enum PendingNavigationAction: Sendable, Equatable {
    case selectObject(UUID?)
    case switchTab(EditorTab)
    case switchLayout(UUID)
    case navigateBack
    case performUndo
}

@Observable
@MainActor
final class LayoutEditorViewModel {
    let projectID: UUID
    let session: any ProjectSessionProtocol
    let onBack: () -> Void

    var tab: EditorTab = .floorPlan
    var selectionID: UUID?
    var hoverID: UUID?
    var transform = CanvasTransform()
    var inspectorDraft: InspectorDraft?
    var pendingAction: PendingNavigationAction?

    private var historiesByLayoutID: [UUID: LayoutEditHistory] = [:]

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        onBack: @escaping () -> Void = {}
    ) {
        self.projectID = projectID
        self.session = session
        self.onBack = onBack
    }

    var layouts: [Layout] {
        session.draft(for: projectID)?.layouts ?? []
    }

    var legend: Legend {
        session.draft(for: projectID)?.legend ?? Legend()
    }

    var activeLayoutID: UUID? {
        session.activeLayoutID(for: projectID) ?? layouts.first?.id
    }

    var activeLayout: Layout? {
        guard let activeLayoutID else { return layouts.first }
        return session.layout(id: activeLayoutID, in: projectID) ?? layouts.first
    }

    var selectedObject: LayoutObject? {
        guard let selectionID, let activeLayout else { return nil }
        return activeLayout.objects.first { $0.id == selectionID }
    }

    var currentHistory: LayoutEditHistory {
        get {
            guard let id = activeLayoutID else { return LayoutEditHistory() }
            return historiesByLayoutID[id] ?? LayoutEditHistory()
        }
        set {
            guard let id = activeLayoutID else { return }
            historiesByLayoutID[id] = newValue
        }
    }

    var canUndo: Bool { currentHistory.canUndo }
    var canRedo: Bool { currentHistory.canRedo }

    var hasUnsavedInspectorChanges: Bool {
        guard let selectedObject, let inspectorDraft else { return false }
        return inspectorDraft.applied(to: selectedObject) != selectedObject
    }

    func selectObject(_ objectID: UUID?) {
        if let objectID, let activeLayout {
            guard let target = activeLayout.objects.first(where: { $0.id == objectID }),
                  target.kind.tab == tab.objectTab,
                  target.kind.isSelectable else {
                return
            }
        }
        guard objectID != selectionID else { return }
        if hasUnsavedInspectorChanges {
            pendingAction = .selectObject(objectID)
            return
        }
        applySelection(objectID)
    }

    func selectTab(_ newTab: EditorTab) {
        guard newTab != tab else { return }
        if hasUnsavedInspectorChanges {
            pendingAction = .switchTab(newTab)
            return
        }
        tab = newTab
        applySelection(nil)
    }

    func selectLayout(_ layoutID: UUID) {
        guard layoutID != activeLayoutID else { return }
        if hasUnsavedInspectorChanges {
            pendingAction = .switchLayout(layoutID)
            return
        }
        session.setActiveLayoutID(layoutID, for: projectID)
        applySelection(nil)
    }

    func requestBack() {
        if hasUnsavedInspectorChanges {
            pendingAction = .navigateBack
            return
        }
        onBack()
    }

    func applySelection(_ objectID: UUID?) {
        selectionID = objectID
        if let selected = selectedObject {
            inspectorDraft = InspectorDraft(object: selected)
        } else {
            inspectorDraft = nil
        }
    }

    func commitEdit(_ edit: LayoutEdit) {
        guard let layout = activeLayout else { return }
        let updated = LayoutEditing.apply(edit, to: layout)
        currentHistory.record(edit)
        session.updateLayout(updated, in: projectID)
    }

    func applyHistoryEdit(_ edit: LayoutEdit) {
        guard let layout = activeLayout else { return }
        let updated = LayoutEditing.apply(edit, to: layout)
        session.updateLayout(updated, in: projectID)
        if let selected = selectedObject {
            inspectorDraft = InspectorDraft(object: selected)
        } else {
            selectionID = nil
            inspectorDraft = nil
        }
    }
}

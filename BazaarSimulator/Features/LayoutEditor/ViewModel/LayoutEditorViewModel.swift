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
    case selectGroup(BoothGroupKind)
    case toggleBooth(UUID)
    case switchTool(EditorTool)
    case switchTab(EditorTab)
    case switchLayout(UUID)
    case navigateBack
    case performUndo
    case performRedo
}

@Observable
@MainActor
final class LayoutEditorViewModel {
    let projectID: UUID
    private let session: any ProjectSessionProtocol
    private let onBack: () -> Void

    var tab: EditorTab = .floorPlan
    var tool: EditorTool = .select
    var selectionID: UUID?
    var hoverID: UUID?
    var groupSelection: GroupSelection?
    var hoveredGroup: BoothGroupKind?
    var librarySearch: String = ""
    var libraryCategory: CatalogCategory?
    var inspectorPanelTab: InspectorPanelTab = .library
    private(set) var cachedBoothTemplates: [BoothTemplate] = []
    var transform = CanvasTransform()
    var hasFittedTransform = false
    private(set) var issues: [LayoutIssue] = []
    private(set) var nameGroups: [BoothGroup] = []
    private(set) var sizeGroups: [BoothGroup] = []
    @ObservationIgnored private var groupedObjects: [LayoutObject] = []
    @ObservationIgnored private var isBatchingRefresh = false

    var inspectorDraft: InspectorDraft? {
        didSet {
            if !isBatchingRefresh { refreshDerivedState() }
        }
    }
    var groupDraft: GroupInspectorDraft? {
        didSet {
            if !isBatchingRefresh { refreshDerivedState() }
        }
    }
    var pendingAction: PendingNavigationAction?
    var pendingGroupDelete: Int?

    private var historiesByLayoutID: [UUID: LayoutEditHistory] = [:]

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        onBack: @escaping () -> Void = {}
    ) {
        self.projectID = projectID
        self.session = session
        self.onBack = onBack
        refreshTemplates()
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
        if groupSelection != nil { return groupDraft?.hasChanges ?? false }
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
        guard objectID != selectionID || groupSelection != nil else { return }
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
        tool = .select
        applySelection(nil)
    }

    func selectLayout(_ layoutID: UUID) {
        guard layoutID != activeLayoutID else { return }
        if hasUnsavedInspectorChanges {
            pendingAction = .switchLayout(layoutID)
            return
        }
        withSingleRefresh {
            session.setActiveLayoutID(layoutID, for: projectID)
            hasFittedTransform = false
            applySelection(nil)
        }
    }

    func requestBack() {
        if hasUnsavedInspectorChanges {
            pendingAction = .navigateBack
            return
        }
        onBack()
    }

    func applySelection(_ objectID: UUID?) {
        hoveredGroup = nil
        groupSelection = nil
        groupDraft = nil
        selectionID = objectID
        if let selected = selectedObject {
            inspectorDraft = InspectorDraft(object: selected)
        } else {
            inspectorDraft = nil
        }
    }

    func withSingleRefresh(_ body: () -> Void) {
        let wasBatching = isBatchingRefresh
        isBatchingRefresh = true
        body()
        isBatchingRefresh = wasBatching
        if !wasBatching {
            refreshDerivedState()
        }
    }

    func refreshDerivedState() {
        refreshGroups()
        refreshTemplates()
        guard let previewLayout = layoutWithInspectorDraft else {
            issues = []
            return
        }
        issues = LayoutValidator.issues(in: previewLayout)
    }

    private func refreshGroups() {
        guard let layout = activeLayout else {
            groupedObjects = []
            nameGroups = []
            sizeGroups = []
            return
        }
        guard layout.objects != groupedObjects else { return }
        groupedObjects = layout.objects
        nameGroups = BoothGrouping.nameGroups(in: layout)
        sizeGroups = BoothGrouping.sizeGroups(in: layout)
    }

    private func refreshTemplates() {
        cachedBoothTemplates = BoothTemplates.templates(layouts: layouts, legend: legend)
    }

    func commitEdit(_ edit: LayoutEdit) {
        guard let layout = activeLayout else { return }
        let updated = LayoutEditing.apply(edit, to: layout)
        currentHistory.record(edit)
        session.updateLayout(updated, in: projectID)
        if !isBatchingRefresh { refreshDerivedState() }
    }

    func applyHistoryEdit(_ edit: LayoutEdit) {
        guard let layout = activeLayout else { return }
        withSingleRefresh {
            let updated = LayoutEditing.apply(edit, to: layout)
            session.updateLayout(updated, in: projectID)
            if let selected = selectedObject {
                inspectorDraft = InspectorDraft(object: selected)
            } else if let selection = groupSelection {
                let remaining = selection.memberIDs.intersection(updated.objects.map(\.id))
                applyMemberSelection(remaining, kind: selection.kind)
            } else {
                selectionID = nil
                inspectorDraft = nil
            }
        }
    }

    func executePendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .selectObject(let objectID):
            applySelection(objectID)
        case .selectGroup, .toggleBooth:
            executeGroupAction(action)
        case .switchTab(let newTab):
            tab = newTab
            tool = .select
            applySelection(nil)
        case .switchTool(let newTool):
            performSelectTool(newTool)
        case .switchLayout(let layoutID):
            executeSwitchLayout(layoutID)
        case .navigateBack:
            onBack()
        case .performUndo:
            executeHistoryAction(isUndo: true)
        case .performRedo:
            executeHistoryAction(isUndo: false)
        }
    }

    private func executeSwitchLayout(_ layoutID: UUID) {
        withSingleRefresh {
            session.setActiveLayoutID(layoutID, for: projectID)
            hasFittedTransform = false
            applySelection(nil)
        }
    }

    private func executeHistoryAction(isUndo: Bool) {
        let edit = isUndo ? currentHistory.undo() : currentHistory.redo()
        if let edit {
            applyHistoryEdit(edit)
        }
    }
}

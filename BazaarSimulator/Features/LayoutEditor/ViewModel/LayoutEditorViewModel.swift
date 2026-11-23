import Foundation
import Observation
import simd

struct CategoryOption: Identifiable, Hashable, Sendable {
    var id: BoothType?
    var name: String

    static let boothOptions: [CategoryOption] =
        [CategoryOption(id: nil, name: "Unassigned")]
        + BoothType.allCases.map { CategoryOption(id: $0, name: $0.displayName) }
}

struct DoorAdviceDisplay: Hashable, Sendable {
    let message: String
    let actionTitle: String
    let suggestedDirection: DoorDirection
}

@Observable
@MainActor
final class LayoutEditorViewModel {
    let projectID: UUID
    let session: any ProjectSessionProtocol
    private let onBack: () -> Void
    @ObservationIgnored private let defaults: UserDefaults
    static let canvasBackgroundKey = "layoutEditor.canvasBackground"

    var canvasBackground: CanvasBackground {
        didSet { defaults.set(canvasBackground.rawValue, forKey: Self.canvasBackgroundKey) }
    }

    var activeLayer: EditorLayer = .booths
    var hiddenLayers: Set<EditorLayer> = []
    var showVisitorFlow: Bool = false
    var transientHint: String?
    @ObservationIgnored var transientHintTask: Task<Void, Never>?
    var tool: EditorTool = .select
    var selectionID: UUID?
    var hoverID: UUID?
    var groupSelection: GroupSelection?
    var hoveredGroup: BoothGroupKind?
    var librarySearch: String = ""
    var inspectorPanelTab: InspectorPanelTab = .library
    var cachedBoothTemplates: [BoothTemplate] = []
    var placementRotationDegrees: Int = 0
    var placementPreview: PlacementCandidate?
    var wallDrawing: WallDrawing?
    var selectedWallItemID: String = "wall"
    var dragState = CanvasDragState()
    @ObservationIgnored var activeToolHandler: (any EditorToolHandling)?
    var transform = CanvasTransform()
    var clipboard: [LayoutObject] = []
    @ObservationIgnored var clipboardPasteCount = 0
    var hasFittedTransform = false
    @ObservationIgnored var autoFitTransform: CanvasTransform?
    private(set) var issues: [LayoutIssue] = []
    private(set) var nameGroups: [BoothGroup] = []
    private(set) var sizeGroups: [BoothGroup] = []
    @ObservationIgnored private var groupedObjects: [LayoutObject] = []
    @ObservationIgnored private var isBatchingRefresh = false
    @ObservationIgnored var templateKey: Int?

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
    var pendingGroupDelete: Int?

    private var historiesByLayoutID: [UUID: LayoutEditHistory] = [:]

    init(
        projectID: UUID,
        session: any ProjectSessionProtocol,
        defaults: UserDefaults = .standard,
        onBack: @escaping () -> Void = {}
    ) {
        self.projectID = projectID
        self.session = session
        self.defaults = defaults
        self.canvasBackground = defaults.string(forKey: Self.canvasBackgroundKey)
            .flatMap(CanvasBackground.init(rawValue:)) ?? .grey
        self.onBack = onBack
        refreshTemplates()
    }

    var projectName: String {
        session.draft(for: projectID)?.name ?? ""
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

    var activeLayoutTitle: String {
        if let name = activeLayout?.name.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        let index = (layouts.firstIndex { $0.id == activeLayoutID } ?? 0) + 1
        return "Layout \(index)"
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

    func sealHistory() {
        currentHistory.seal()
    }

    func selectObject(_ objectID: UUID?) {
        if let objectID, let activeLayout {
            guard let target = activeLayout.objects.first(where: { $0.id == objectID }),
                  target.kind.layer == activeLayer,
                  target.kind.isSelectable else {
                return
            }
        }
        guard objectID != selectionID || groupSelection != nil else { return }
        applySelection(objectID)
    }

    func selectLayer(_ newLayer: EditorLayer) {
        guard newLayer != activeLayer else { return }
        activeLayer = newLayer
        if newLayer == .structure { inspectorPanelTab = .library }
        selectTool(.select)
        applySelection(nil)
    }

    func selectLayout(_ layoutID: UUID) {
        guard layoutID != activeLayoutID else { return }
        withSingleRefresh {
            session.setActiveLayoutID(layoutID, for: projectID)
            hasFittedTransform = false
            applySelection(nil)
        }
    }

    func requestBack() {
        onBack()
    }

    func applySelection(_ objectID: UUID?) {
        if objectID != selectionID || groupSelection != nil {
            sealHistory()
        }
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

    func commitEdit(_ edit: LayoutEdit, coalesceKey: String? = nil) {
        guard let layout = activeLayout else { return }
        let updated = LayoutEditing.apply(edit, to: layout)
        currentHistory.record(edit, coalesceKey: coalesceKey)
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
}

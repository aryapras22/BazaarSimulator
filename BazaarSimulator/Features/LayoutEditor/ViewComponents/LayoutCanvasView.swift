import SwiftUI
import simd

enum CanvasContextAction: Sendable, Equatable {
    case rotate(UUID)
    case duplicate(UUID)
    case resetOpenSides(UUID)
    case delete(UUID)
    case addObject(kind: LayoutObjectKind, atWorld: SIMD2<Double>)
}

struct CanvasIssueSnapshot: Sendable, Equatable {
    var warningObjectIDs: Set<UUID> = []
    var blockedSidesByBoothID: [UUID: OpenSides] = [:]
}

struct CanvasDisplaySnapshot: Sendable {
    var layout: Layout
    var legend: Legend
    var tab: EditorTab
    var selectionID: UUID?
    var hoverID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var hoveredGroupMemberIDs: Set<UUID> = []
    var groupClusters: [GroupClusterDisplay] = []
    var hasUnsavedChanges: Bool = false
    var issues: CanvasIssueSnapshot = CanvasIssueSnapshot()
}

struct LayoutCanvasView: View {
    let snapshot: CanvasDisplaySnapshot
    @Binding var transform: CanvasTransform
    var isFocused: FocusState<Bool>.Binding
    var excludedTrailingWidth: CGFloat = 0
    var onSelect: (UUID?) -> Void = { _ in }
    var onHover: (UUID?) -> Void = { _ in }
    var onToggleSelection: (UUID) -> Void = { _ in }
    var onDoubleClick: (UUID, Bool) -> Void = { _, _ in }
    var onPointerMove: (SIMD2<Double>?) -> Void = { _ in }
    var onDragEnded: (UUID, SIMD2<Double>, Bool) -> Void = { _, _, _ in }
    var onContextAction: (CanvasContextAction) -> Void = { _ in }
    var onInteract: () -> Void = {}
    var tool: EditorTool = .select
    var onDrawBlockedArea: (Placement) -> Void = { _ in }
    var onCancelTool: () -> Void = {}
    var onResizeEnded: (UUID, Placement) -> Void = { _, _ in }
    var onDropLibraryItem: (String, SIMD2<Double>) -> Void = { _, _ in }
    var onCommitPlacement: (Bool) -> Void = { _ in }
    var onCommitDoorPlacement: (Bool, String) -> Void = { _, _ in }
    var constrainDelta: ((UUID, SIMD2<Double>) -> SIMD2<Double>)?
    var pointer: CanvasPointer?
    var wallDrawing: WallDrawing?
    var onWallClick: (Bool) -> Void = { _ in }
    var onWallDoubleClick: () -> Void = {}
    var onWallKey: (Character) -> Bool = { _ in false }
    var onWallReturn: () -> Bool = { false }
    var onWallBackspace: () -> Bool = { false }
    var onWallFinish: () -> Void = {}

    @State var activeDragObjectID: UUID?
    @State var activeDragDeltaWorld: SIMD2<Double> = .zero
    @State var activeResize: ActiveResize?
    @State var hoveredHandle: ResizeHandle?
    @State var isDragCancelled = false
    @State var isDragSuppressed = false
    @State var lastPanLocation: CGPoint?
    @State var dragPointerLocation: CGPoint?
    @State var drawingStartWorld: SIMD2<Double>?
    @State var drawingCurrentWorld: SIMD2<Double>?
    @State var clickSequence = ClickSequence()
    @State var hoverTracker = HoverTracker()
    @State var lastHoverHit: UUID?
    @State var lastMagnification: CGFloat = 1

    final class HoverTracker {
        var world: SIMD2<Double> = .zero
    }

    var body: some View {
        Canvas { context, size in
            CanvasSceneRenderer.draw(
                in: &context,
                size: size,
                snapshot: snapshot,
                transform: transform,
                drag: CanvasDragState(
                    objectID: activeDragObjectID,
                    deltaWorld: activeDragDeltaWorld,
                    pointerLocation: dragPointerLocation,
                    drawingStart: drawingStartWorld,
                    drawingCurrent: drawingCurrentWorld,
                    isOptionDown: NSEvent.modifierFlags.contains(.option),
                    resize: activeResize,
                    placementCandidate: pointer?.placementCandidate,
                    placingSource: pointer?.placingSource,
                    wallDrawing: wallDrawing,
                    wallCurrentPointer: pointer?.wallCurrentPointer
                )
            )
        }
        .background(Palette.background)
        .contentShape(Rectangle())
        .onHover { isHovering in
            guard !isHovering else { return }
            onPointerMove(nil)
            hoveredHandle = nil
            if lastHoverHit != nil {
                lastHoverHit = nil
                onHover(nil)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let world = transform.toWorld(SIMD2<Double>(location.x, location.y))
                hoverTracker.world = world
                onPointerMove(world)
                updateHoverState(at: world)
            case .ended:
                onPointerMove(nil)
                hoveredHandle = nil
                if lastHoverHit != nil {
                    lastHoverHit = nil
                    onHover(nil)
                }
            }
        }
        .gesture(canvasGesture)
        .simultaneousGesture(magnificationGesture)
        .overlay {
            CanvasScrollCatcher(excludedTrailingWidth: excludedTrailingWidth) { delta, location, isPrecise, isCmd in
                if !isPrecise || isCmd {
                    let anchor = SIMD2<Double>(Double(location.x), Double(location.y))
                    transform = transform.zoomedForScroll(
                        deltaY: Double(delta.height),
                        isPrecise: isPrecise,
                        around: anchor
                    )
                } else {
                    let panDelta = SIMD2<Double>(Double(delta.width), Double(delta.height))
                    transform = transform.panned(by: panDelta)
                }
            }
        }
        .pointerStyle(canvasPointerStyle)
        .dropDestination(for: String.self) { items, location in
            guard let first = items.first else { return false }
            let world = transform.toWorld(SIMD2<Double>(location.x, location.y))
            onDropLibraryItem(first, world)
            return true
        }
        .focusable()
        .focusEffectDisabled()
        .focused(isFocused)
        .onKeyPress(.escape) {
            if activeResize != nil {
                activeResize = nil
                dragPointerLocation = nil
                return .handled
            }
            if case .drawWall = tool {
                onWallFinish()
                return .handled
            }
            if drawingStartWorld != nil {
                drawingStartWorld = nil
                drawingCurrentWorld = nil
                return .handled
            }
            if tool == .blockedArea {
                onCancelTool()
                return .handled
            }
            if activeDragObjectID != nil {
                activeDragObjectID = nil
                activeDragDeltaWorld = .zero
                dragPointerLocation = nil
                isDragCancelled = true
                return .handled
            }
            onSelect(nil)
            return .handled
        }
        .onKeyPress(.return) {
            if case .drawWall = tool, onWallReturn() {
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.delete, .deleteForward]) { _ in
            if case .drawWall = tool, onWallBackspace() {
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "0123456789.")) { press in
            if case .drawWall = tool, let char = press.characters.first, onWallKey(char) {
                return .handled
            }
            return .ignored
        }
        .contextMenu {
            contextMenuContent
        }
    }

    private var canvasPointerStyle: PointerStyle {
        if let resize = activeResize {
            return .frameResize(position: resize.handle.pointerPosition)
        }
        if let handle = hoveredHandle {
            return .frameResize(position: handle.pointerPosition)
        }
        switch tool {
        case .place, .drawWall:
            return .rectSelection
        default:
            break
        }
        return tool == .blockedArea ? .rectSelection : .default
    }

    private var canvasGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { handleDragChanged($0) }
            .onEnded { handleDragEnded($0) }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let step = Double(value.magnification / lastMagnification)
                lastMagnification = value.magnification
                let anchor = SIMD2<Double>(value.startLocation.x, value.startLocation.y)
                transform = transform.zoomed(by: step, around: anchor)
            }
            .onEnded { _ in lastMagnification = 1 }
    }
}

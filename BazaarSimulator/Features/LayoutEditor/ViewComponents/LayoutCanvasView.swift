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
    var activeLayer: EditorLayer = .structure
    var hiddenLayers: Set<EditorLayer> = []
    var showVisitorFlow: Bool = false
    var selectionID: UUID?
    var hoverID: UUID?
    var groupMemberIDs: Set<UUID> = []
    var hoveredGroupMemberIDs: Set<UUID> = []
    var groupClusters: [GroupClusterDisplay] = []
    var hasUnsavedChanges: Bool = false
    var issues: CanvasIssueSnapshot = CanvasIssueSnapshot()
    var hoverWorld: SIMD2<Double>?
}

struct LayoutCanvasView: View {
    let snapshot: CanvasDisplaySnapshot
    @Binding var transform: CanvasTransform
    var isFocused: FocusState<Bool>.Binding
    var dragState: CanvasDragState = CanvasDragState()
    var tool: EditorTool = .select
    var onPointerPress: (CanvasPointerEvent) -> Void = { _ in }
    var onPointerMove: (CanvasPointerEvent) -> Void = { _ in }
    var onPointerRelease: (CanvasPointerEvent) -> Void = { _ in }
    var onPointerDoubleClick: (CanvasPointerEvent) -> Void = { _ in }
    var onCanvasKey: (CanvasKey) -> Bool = { _ in false }
    var onCancelTool: () -> Void = {}
    var onHoverWorld: (SIMD2<Double>?) -> Void = { _ in }
    var onHover: (UUID?) -> Void = { _ in }
    var onContextAction: (CanvasContextAction) -> Void = { _ in }
    var onInteract: () -> Void = {}
    var onNudge: (SIMD2<Double>) -> Void = { _ in }
    var onDropLibraryItem: (String, SIMD2<Double>) -> Void = { _, _ in }

    @State var isDragging = false
    @State var hoveredHandle: ResizeHandle?
    @State var isSpaceDown = false
    @State var lastPanLocation: CGPoint?
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
                drag: dragState
            )
        }
        .background(Palette.background)
        .contentShape(Rectangle())
        .onHover { isHovering in
            guard !isHovering else { return }
            onHoverWorld(nil)
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
                onHoverWorld(world)
                updateHoverState(at: world)
                let event = makePointerEvent(at: location)
                onPointerMove(event)
            case .ended:
                onHoverWorld(nil)
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
            CanvasScrollCatcher(
                onScroll: { delta, location, isPrecise, isCmd in
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
                },
                onPan: { panDelta in
                    transform = transform.panned(by: panDelta)
                }
            )
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
        .onKeyPress(.space, phases: [.down, .up]) { press in
            isSpaceDown = (press.phase == .down)
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow]) { press in
            let key: CanvasKey
            switch press.key {
            case .upArrow: key = .upArrow
            case .downArrow: key = .downArrow
            case .leftArrow: key = .leftArrow
            case .rightArrow: key = .rightArrow
            default: return .ignored
            }
            if onCanvasKey(key) {
                return .handled
            }
            let step = press.modifiers.contains(.shift)
                ? LayoutEditorViewModel.shiftNudgeStepM
                : LayoutEditorViewModel.gridSnapCellM
            switch press.key {
            case .upArrow: onNudge(SIMD2<Double>(0, -step))
            case .downArrow: onNudge(SIMD2<Double>(0, step))
            case .leftArrow: onNudge(SIMD2<Double>(-step, 0))
            case .rightArrow: onNudge(SIMD2<Double>(step, 0))
            default: return .ignored
            }
            return .handled
        }
        .onKeyPress(.escape) {
            if onCanvasKey(.escape) {
                return .handled
            }
            onCancelTool()
            return .handled
        }
        .onKeyPress(.return) {
            if onCanvasKey(.returnKey) {
                return .handled
            }
            return .ignored
        }
        .onKeyPress(keys: [.delete, .deleteForward]) { _ in
            if onCanvasKey(.delete) {
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "0123456789.")) { press in
            if let char = press.characters.first, onCanvasKey(.character(char)) {
                return .handled
            }
            return .ignored
        }
        .contextMenu {
            contextMenuContent
        }
    }

    private var canvasPointerStyle: PointerStyle {
        if let resize = dragState.resize {
            return .frameResize(position: resize.handle.pointerPosition)
        }
        if let handle = hoveredHandle {
            return .frameResize(position: handle.pointerPosition)
        }
        switch tool {
        case .place, .drawWall, .room, .blockedArea:
            return .rectSelection
        default:
            return .default
        }
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

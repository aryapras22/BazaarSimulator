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

    @State private var activeDragObjectID: UUID?
    @State private var activeDragDeltaWorld: SIMD2<Double> = .zero
    @State private var activeResize: ActiveResize?
    @State private var hoveredHandle: ResizeHandle?
    @State private var isDragCancelled = false
    @State private var isDragSuppressed = false
    @State private var lastPanLocation: CGPoint?
    @State private var dragPointerLocation: CGPoint?
    @State private var drawingStartWorld: SIMD2<Double>?
    @State private var drawingCurrentWorld: SIMD2<Double>?
    @State private var clickSequence = ClickSequence()
    @State private var hoverTracker = HoverTracker()
    @State private var lastHoverHit: UUID?
    @State private var lastMagnification: CGFloat = 1

    private final class HoverTracker {
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
                    resize: activeResize
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
        .focusable()
        .focusEffectDisabled()
        .focused(isFocused)
        .onKeyPress(.escape) {
            if activeResize != nil {
                activeResize = nil
                dragPointerLocation = nil
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

// MARK: - Interactions

extension LayoutCanvasView {
    @ViewBuilder
    private var contextMenuContent: some View {
        if tool == .select && snapshot.tab == .floorPlan {
            let hitID = LayoutHitTester.object(at: hoverTracker.world, in: snapshot.layout, tab: snapshot.tab)
            if let hitID,
                let target = snapshot.layout.objects.first(where: { $0.id == hitID }),
                target.kind.isMovable {
                if target.kind.isRotatable {
                    Button("Rotate 90°") { onContextAction(.rotate(hitID)) }
                }
                Button("Duplicate") { onContextAction(.duplicate(hitID)) }
                if target.kind == .booth {
                    Button("Reset open sides") { onContextAction(.resetOpenSides(hitID)) }
                }
                Divider()
                Button("Delete", role: .destructive) { onContextAction(.delete(hitID)) }
            } else {
                Button("Add Booth Here") { onContextAction(.addObject(kind: .booth, atWorld: hoverTracker.world)) }
                Button("Add Table Here") { onContextAction(.addObject(kind: .table, atWorld: hoverTracker.world)) }
                Button("Add Fixture Here") { onContextAction(.addObject(kind: .fixture, atWorld: hoverTracker.world)) }
                Button("Add Rail Here") { onContextAction(.addObject(kind: .rail, atWorld: hoverTracker.world)) }
            }
        }
    }

    private func updateHoverState(at world: SIMD2<Double>) {
        if snapshot.tab == .floorPlan,
           let selectedID = snapshot.selectionID,
           let selected = snapshot.layout.objects.first(where: { $0.id == selectedID }),
           selected.kind.hasResizeHandles {
            hoveredHandle = PlacementResizing.hitTest(
                placement: selected.placement,
                pointerWorld: world,
                pointsPerMetre: transform.scale
            )
        } else {
            hoveredHandle = nil
        }
        let hit = LayoutHitTester.object(at: world, in: snapshot.layout, tab: snapshot.tab)
        if hit != lastHoverHit {
            lastHoverHit = hit
            onHover(hit)
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        guard !isDragCancelled && !isDragSuppressed else { return }
        let distance = hypot(value.translation.width, value.translation.height)
        guard distance >= 2.0 else { return }

        if tool == .blockedArea && snapshot.tab == .floorPlan {
            handleDrawingDragChanged(value)
            return
        }

        if activeDragObjectID == nil && lastPanLocation == nil && activeResize == nil {
            startDragOrPan(at: value.startLocation)
        }

        if let resize = activeResize {
            dragPointerLocation = value.location
            let deltaWorld = SIMD2<Double>(
                Double(value.translation.width) / transform.scale,
                Double(value.translation.height) / transform.scale
            )
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            activeResize?.preview = PlacementResizing.resized(
                placement: resize.initialPlacement,
                handle: resize.handle,
                deltaWorld: deltaWorld,
                snapped: !isOptionDown
            )
        } else if activeDragObjectID != nil {
            dragPointerLocation = value.location
            activeDragDeltaWorld = SIMD2<Double>(
                Double(value.translation.width) / transform.scale,
                Double(value.translation.height) / transform.scale
            )
        } else if let previous = lastPanLocation {
            let delta = SIMD2<Double>(
                Double(value.location.x - previous.x),
                Double(value.location.y - previous.y)
            )
            transform = transform.panned(by: delta)
            lastPanLocation = value.location
        }
    }

    private func handleDrawingDragChanged(_ value: DragGesture.Value) {
        let currentWorld = transform.toWorld(SIMD2<Double>(value.location.x, value.location.y))
        if drawingStartWorld == nil {
            onInteract()
            drawingStartWorld = transform.toWorld(SIMD2<Double>(value.startLocation.x, value.startLocation.y))
        }
        drawingCurrentWorld = currentWorld
    }

    private func startDragOrPan(at location: CGPoint) {
        onInteract()
        let startWorld = transform.toWorld(SIMD2<Double>(location.x, location.y))
        if snapshot.tab == .floorPlan,
           let selectedID = snapshot.selectionID,
           let selected = snapshot.layout.objects.first(where: { $0.id == selectedID }),
           selected.kind.hasResizeHandles,
           let handle = PlacementResizing.hitTest(
               placement: selected.placement,
               pointerWorld: startWorld,
               pointsPerMetre: transform.scale
           ) {
            activeResize = ActiveResize(
                objectID: selectedID,
                handle: handle,
                initialPlacement: selected.placement,
                preview: selected.placement
            )
            return
        }

        guard let hitID = LayoutHitTester.object(at: startWorld, in: snapshot.layout, tab: snapshot.tab),
              let object = snapshot.layout.objects.first(where: { $0.id == hitID }),
              object.kind.isMovable else {
            lastPanLocation = location
            return
        }
        if object.kind == .closedArea && snapshot.selectionID != hitID {
            lastPanLocation = location
        } else {
            if snapshot.selectionID != hitID {
                onSelect(hitID)
                if snapshot.hasUnsavedChanges {
                    isDragSuppressed = true
                    return
                }
            }
            activeDragObjectID = hitID
        }
    }

    private func handleClick(on hitID: UUID?) {
        let modifiers = NSEvent.modifierFlags
        let isDouble = clickSequence.register(
            id: hitID,
            at: ProcessInfo.processInfo.systemUptime,
            interval: NSEvent.doubleClickInterval
        )
        if modifiers.contains(.shift), let hitID {
            onToggleSelection(hitID)
        } else if isDouble, let hitID {
            onDoubleClick(hitID, modifiers.contains(.option))
        } else {
            onSelect(hitID)
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        if isDragCancelled || isDragSuppressed {
            isDragCancelled = false
            isDragSuppressed = false
            activeDragObjectID = nil
            activeDragDeltaWorld = .zero
            dragPointerLocation = nil
            lastPanLocation = nil
            drawingStartWorld = nil
            drawingCurrentWorld = nil
            activeResize = nil
            return
        }
        if let resize = activeResize {
            onResizeEnded(resize.objectID, resize.preview)
            activeResize = nil
            dragPointerLocation = nil
            return
        }
        if tool == .blockedArea {
            if let start = drawingStartWorld, let current = drawingCurrentWorld {
                let isOptionDown = NSEvent.modifierFlags.contains(.option)
                if let placement = BlockedAreaDrawing.placement(
                    from: start,
                    to: current,
                    snapped: !isOptionDown
                ) {
                    onDrawBlockedArea(placement)
                }
            }
            drawingStartWorld = nil
            drawingCurrentWorld = nil
            return
        }
        let distance = hypot(value.translation.width, value.translation.height)
        if let draggedID = activeDragObjectID {
            let isOptionDown = NSEvent.modifierFlags.contains(.option)
            onDragEnded(draggedID, activeDragDeltaWorld, isOptionDown)
            activeDragObjectID = nil
            activeDragDeltaWorld = .zero
            dragPointerLocation = nil
            return
        }
        lastPanLocation = nil
        if distance < 2.0 {
            onInteract()
            let clickWorld = transform.toWorld(SIMD2<Double>(value.location.x, value.location.y))
            let hitID = LayoutHitTester.object(at: clickWorld, in: snapshot.layout, tab: snapshot.tab)
            handleClick(on: hitID)
        }
    }
}

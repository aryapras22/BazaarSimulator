import SwiftUI

extension LayoutCanvasView {
    @ViewBuilder
    var contextMenuContent: some View {
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

    func updateHoverState(at world: SIMD2<Double>) {
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
        let hitID = LayoutHitTester.object(at: world, in: snapshot.layout, tab: snapshot.tab)
        if hitID != lastHoverHit {
            lastHoverHit = hitID
            onHover(hitID)
        }
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        if isDragCancelled { return }
        if isDragSuppressed {
            applyPan(currentPoint: value.location, translation: value.translation)
            return
        }
        if tool == .blockedArea {
            updateBlockedAreaDrag(value)
            return
        }
        if activeResize == nil && activeDragObjectID == nil && lastPanLocation == nil {
            startDragInteraction(value)
        }
        if activeResize != nil {
            updateResizeDrag(currentPoint: value.location)
            return
        }
        if activeDragObjectID != nil {
            updateObjectDrag(startLocation: value.startLocation, currentLocation: value.location)
            return
        }
        applyPan(currentPoint: value.location, translation: value.translation)
    }

    private func applyPan(currentPoint: CGPoint, translation: CGSize) {
        let distance = hypot(translation.width, translation.height)
        guard distance > 2.0 else { return }
        let delta = lastPanLocation.map { CGPoint(x: currentPoint.x - $0.x, y: currentPoint.y - $0.y) }
            ?? CGPoint(x: translation.width, y: translation.height)
        transform = transform.panned(by: SIMD2<Double>(Double(delta.x), Double(delta.y)))
        lastPanLocation = currentPoint
    }

    private func updateBlockedAreaDrag(_ value: DragGesture.Value) {
        if drawingStartWorld == nil {
            drawingStartWorld = transform.toWorld(SIMD2<Double>(value.startLocation.x, value.startLocation.y))
        }
        drawingCurrentWorld = transform.toWorld(SIMD2<Double>(value.location.x, value.location.y))
    }

    private func startDragInteraction(_ value: DragGesture.Value) {
        let startWorld = transform.toWorld(SIMD2<Double>(value.startLocation.x, value.startLocation.y))
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
              let target = snapshot.layout.objects.first(where: { $0.id == hitID }),
              target.kind.isMovable else { return }
        if target.kind == .closedArea && snapshot.selectionID != hitID {
            return
        }
        if snapshot.selectionID != hitID {
            onSelect(hitID)
            if snapshot.hasUnsavedChanges {
                isDragSuppressed = true
                return
            }
        }
        activeDragObjectID = hitID
        activeDragDeltaWorld = .zero
    }

    private func updateResizeDrag(currentPoint: CGPoint) {
        guard let resize = activeResize else { return }
        let currentWorld = transform.toWorld(SIMD2<Double>(currentPoint.x, currentPoint.y))
        let isOptionDown = NSEvent.modifierFlags.contains(.option)
        let handlePos = PlacementResizing.handlePosition(for: resize.handle, in: resize.initialPlacement)
        let deltaWorld = currentWorld - handlePos
        activeResize?.preview = PlacementResizing.resized(
            placement: resize.initialPlacement,
            handle: resize.handle,
            deltaWorld: deltaWorld,
            snapped: !isOptionDown
        )
        dragPointerLocation = currentPoint
    }

    private func updateObjectDrag(startLocation: CGPoint, currentLocation: CGPoint) {
        let currentWorld = transform.toWorld(SIMD2<Double>(currentLocation.x, currentLocation.y))
        let startWorld = transform.toWorld(SIMD2<Double>(startLocation.x, startLocation.y))
        var rawDelta = currentWorld - startWorld
        if let activeDragObjectID, let constrainDelta {
            rawDelta = constrainDelta(activeDragObjectID, rawDelta)
        }
        activeDragDeltaWorld = rawDelta
        dragPointerLocation = currentLocation
    }

    func handleClick(on hitID: UUID?) {
        let modifiers = NSEvent.modifierFlags
        let isDouble = clickSequence.register(
            id: hitID,
            at: ProcessInfo.processInfo.systemUptime,
            interval: NSEvent.doubleClickInterval
        )
        if case .drawWall = tool {
            if isDouble {
                onWallDoubleClick()
            } else {
                let isShiftDown = modifiers.contains(.shift)
                onWallClick(isShiftDown)
            }
            return
        }
        if case .placeDoor(let itemID) = tool {
            let isShiftDown = modifiers.contains(.shift)
            onCommitDoorPlacement(!isShiftDown, itemID)
            return
        }
        if case .place = tool {
            let isShiftDown = modifiers.contains(.shift)
            onCommitPlacement(!isShiftDown)
            return
        }
        if modifiers.contains(.shift), let hitID {
            onToggleSelection(hitID)
        } else if isDouble, let hitID {
            onDoubleClick(hitID, modifiers.contains(.option))
        } else {
            onSelect(hitID)
        }
    }

    func handleDragEnded(_ value: DragGesture.Value) {
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

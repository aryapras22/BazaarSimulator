import SwiftUI

extension LayoutCanvasView {
    @ViewBuilder
    var contextMenuContent: some View {
        if tool == .select {
            let hitID = LayoutHitTester.object(at: hoverTracker.world, in: snapshot.layout, layer: snapshot.activeLayer)
            if let hitID,
                let target = snapshot.layout.objects.first(where: { $0.id == hitID }),
                target.kind.isMovable {
                let isInGroupSelection = snapshot.groupMemberIDs.contains(hitID)
                if target.kind.isRotatable && !isInGroupSelection {
                    Button("Rotate 90°") { onContextAction(.rotate(hitID)) }
                }
                if !isInGroupSelection {
                    Button("Duplicate") { onContextAction(.duplicate(hitID)) }
                }
                if target.kind == .booth {
                    Button("Reset open sides") { onContextAction(.resetOpenSides(hitID)) }
                }
                Divider()
                Button("Delete", role: .destructive) { onContextAction(.delete(hitID)) }
            } else {
                if snapshot.activeLayer == .booths {
                    Button("Add Booth Here") { onContextAction(.addObject(kind: .booth, atWorld: hoverTracker.world)) }
                } else {
                    Button("Add Block Here") { onContextAction(.addObject(kind: .block, atWorld: hoverTracker.world)) }
                }
            }
        }
    }

    func updateHoverState(at world: SIMD2<Double>) {
        if let selectedID = snapshot.selectionID,
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
        let hitID = LayoutHitTester.object(at: world, in: snapshot.layout, layer: snapshot.activeLayer)
        if hitID != lastHoverHit {
            lastHoverHit = hitID
            onHover(hitID)
        }
    }

    func makePointerEvent(at viewPoint: CGPoint, button: CanvasMouseButton = .left) -> CanvasPointerEvent {
        let worldPoint = transform.toWorld(SIMD2<Double>(Double(viewPoint.x), Double(viewPoint.y)))
        let hitObjectID = LayoutHitTester.object(at: worldPoint, in: snapshot.layout, layer: snapshot.activeLayer)
        let modifiers = CanvasModifiers(modifierFlags: NSEvent.modifierFlags)
        return CanvasPointerEvent(
            worldPoint: worldPoint,
            viewPoint: viewPoint,
            button: button,
            modifiers: modifiers,
            hitObjectID: hitObjectID,
            pointsPerMetre: transform.scale
        )
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        if isSpaceDown {
            applyPan(currentPoint: value.location, translation: value.translation)
            return
        }
        if !isDragging {
            isDragging = true
            let pressEvent = makePointerEvent(at: value.startLocation)
            onPointerPress(pressEvent)
        }
        let moveEvent = makePointerEvent(at: value.location)
        onPointerMove(moveEvent)
    }

    func handleDragEnded(_ value: DragGesture.Value) {
        if isSpaceDown || lastPanLocation != nil {
            lastPanLocation = nil
            isDragging = false
            return
        }
        isDragging = false
        onInteract()
        let releaseEvent = makePointerEvent(at: value.location)
        let isPastThreshold = SelectGesture.isPastThreshold(value.translation)
        if !isPastThreshold {
            let isDouble = clickSequence.register(
                id: releaseEvent.hitObjectID,
                point: releaseEvent.viewPoint,
                at: ProcessInfo.processInfo.systemUptime,
                interval: NSEvent.doubleClickInterval
            )
            if isDouble {
                // Placing tools ignore double clicks, so a fast second click on empty canvas must still place.
                if releaseEvent.hitObjectID == nil { onPointerRelease(releaseEvent) }
                onPointerDoubleClick(releaseEvent)
                return
            }
        }
        onPointerRelease(releaseEvent)
    }

    func applyPan(currentPoint: CGPoint, translation: CGSize) {
        let distance = hypot(translation.width, translation.height)
        guard distance > 2.0 else { return }
        let delta = lastPanLocation.map { CGPoint(x: currentPoint.x - $0.x, y: currentPoint.y - $0.y) }
            ?? CGPoint(x: translation.width, y: translation.height)
        transform = transform.panned(by: SIMD2<Double>(Double(delta.x), Double(delta.y)))
        lastPanLocation = currentPoint
    }
}

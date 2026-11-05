import CoreGraphics
import Foundation
import simd

@MainActor
final class SelectTool: EditorToolHandling {
    let tool: EditorTool = .select

    private var pressPoint: SIMD2<Double> = .zero
    var pressViewPoint: CGPoint = .zero
    private var activeResize: ActiveResize?
    var activeNodeDrag: ActiveNodeDrag?
    private var dragCandidateID: UUID?
    private var activeDragObjectID: UUID?
    private var activeDragDeltaWorld: SIMD2<Double> = .zero
    private var marqueeStartWorld: SIMD2<Double>?
    private var marqueeCurrentWorld: SIMD2<Double>?

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        pressPoint = event.worldPoint
        pressViewPoint = event.viewPoint
        resetGesture()

        if context.activeLayer == .structure {
            let graph = WallGraph(layout: context.layout)
            let hitTolerance = Snapper.tolerance(pointsPerMetre: event.pointsPerMetre)
            if let node = graph.nearestNode(to: event.worldPoint, maximumDistance: hitTolerance) {
                let isOptionDown = event.modifiers.contains(.option)
                let targetWallID = (context.selectionID.flatMap { sel in
                    node.incidents.first(where: { $0.wallID == sel })?.wallID
                }) ?? event.hitObjectID ?? node.incidents.first?.wallID

                activeNodeDrag = ActiveNodeDrag(
                    nodeID: node.id,
                    initialPosition: node.position,
                    targetWallID: targetWallID,
                    isDetach: isOptionDown,
                    initialGraph: graph
                )
                return
            }
        }

        if let selectedID = context.selectionID,
           let selected = context.layout.objects.first(where: { $0.id == selectedID }),
           selected.kind.hasResizeHandles,
           let handle = PlacementResizing.hitTest(
               placement: selected.placement,
               pointerWorld: event.worldPoint,
               pointsPerMetre: event.pointsPerMetre
           ) {
            activeResize = ActiveResize(
                objectID: selectedID,
                handle: handle,
                initialPlacement: selected.placement,
                preview: selected.placement
            )
            context.setPreview(CanvasDragState(resize: activeResize))
            return
        }

        guard let hitID = event.hitObjectID,
              let target = context.layout.objects.first(where: { $0.id == hitID }),
              target.kind.isMovable else {
            marqueeStartWorld = event.worldPoint
            marqueeCurrentWorld = event.worldPoint
            return
        }

        if target.kind == .closedArea && context.selectionID != hitID {
            return
        }
        dragCandidateID = hitID
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        if let nodeDrag = activeNodeDrag {
            updateNodeDrag(event: event, nodeDrag: nodeDrag, context: context)
            return
        }

        if let resize = activeResize {
            updateResize(event: event, resize: resize, context: context)
            return
        }

        if let candidateID = dragCandidateID {
            updateCandidateDrag(event: event, candidateID: candidateID, context: context)
            return
        }

        if let start = marqueeStartWorld {
            marqueeCurrentWorld = event.worldPoint
            context.setPreview(CanvasDragState(
                pointerLocation: event.viewPoint,
                marqueeStart: start,
                marqueeCurrent: event.worldPoint
            ))
        }
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        if let nodeDrag = activeNodeDrag {
            finishNodeDrag(event: event, nodeDrag: nodeDrag, context: context)
            return
        }

        if let resize = activeResize {
            finishResize(resize, context: context)
            return
        }

        if let candidateID = dragCandidateID {
            finishCandidate(event: event, candidateID: candidateID, context: context)
            return
        }

        if let start = marqueeStartWorld, let current = marqueeCurrentWorld {
            finishMarquee(event: event, start: start, current: current, context: context)
            return
        }

        if event.hitObjectID == nil {
            if let locked = LayoutHitTester.lockedObject(
                at: event.worldPoint,
                in: context.layout,
                currentLayer: context.activeLayer
            ) {
                let name = locked.kind == .wall ? "Walls" : "\(locked.kind.displayName)s"
                context.showTransientHint("\(name) are locked on this layer")
            }
            context.selectObject(nil)
        }
        resetGesture()
        context.clearPreview()
    }

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {
        if let hitID = event.hitObjectID {
            let bySize = event.modifiers.contains(.option)
            context.selectGroup(containing: hitID, bySize: bySize)
        }
        resetGesture()
        context.clearPreview()
    }

    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        switch key {
        case .escape:
            if isInteracting {
                resetGesture()
                context.clearPreview()
                return true
            }
            if context.selectionID != nil {
                context.selectObject(nil)
                return true
            }
            return false
        case .upArrow:
            context.nudgeSelected(by: SIMD2<Double>(0, -0.25))
            return true
        case .downArrow:
            context.nudgeSelected(by: SIMD2<Double>(0, 0.25))
            return true
        case .leftArrow:
            context.nudgeSelected(by: SIMD2<Double>(-0.25, 0))
            return true
        case .rightArrow:
            context.nudgeSelected(by: SIMD2<Double>(0.25, 0))
            return true
        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        resetGesture()
        context.clearPreview()
    }
}

extension SelectTool {
    var isInteracting: Bool {
        activeNodeDrag != nil
            || activeResize != nil
            || dragCandidateID != nil
            || activeDragObjectID != nil
            || marqueeStartWorld != nil
    }

    func resetGesture() {
        activeNodeDrag = nil
        activeResize = nil
        dragCandidateID = nil
        activeDragObjectID = nil
        activeDragDeltaWorld = .zero
        marqueeStartWorld = nil
        marqueeCurrentWorld = nil
    }

    private func updateResize(event: CanvasPointerEvent, resize: ActiveResize, context: ToolContext) {
        let handlePos = PlacementResizing.handlePosition(for: resize.handle, in: resize.initialPlacement)
        let deltaWorld = event.worldPoint - handlePos
        let isOptionDown = event.modifiers.contains(.option)
        let preview = PlacementResizing.resized(
            placement: resize.initialPlacement,
            handle: resize.handle,
            deltaWorld: deltaWorld,
            snapped: !isOptionDown
        )
        activeResize?.preview = preview
        context.setPreview(CanvasDragState(pointerLocation: event.viewPoint, resize: activeResize))
    }

    private func updateCandidateDrag(event: CanvasPointerEvent, candidateID: UUID, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        guard SelectGesture.isPastThreshold(translation) else { return }

        if activeDragObjectID == nil {
            if context.selectionID != candidateID && !context.groupMemberIDs.contains(candidateID) {
                context.selectObject(candidateID)
            }
            activeDragObjectID = candidateID
        }

        var rawDelta = event.worldPoint - pressPoint
        if event.modifiers.contains(.shift) {
            rawDelta = SelectGesture.lockAxis(rawDelta)
        }

        let isOptionDown = event.modifiers.contains(.option)
        var guides: [SnapGuide] = []

        if let object = context.layout.objects.first(where: { $0.id == candidateID }) {
            if object.kind == .door {
                let reach = Snapper.tolerance(pointsPerMetre: event.pointsPerMetre)
                if !isOptionDown,
                   let host = DoorHosting.nearestHost(to: object.placement.center, in: context.layout, reach: reach),
                   let placement = DoorHosting.placement(
                       width: object.placement.sizeM.x,
                       on: host,
                       near: object.placement.center + rawDelta
                   ) {
                    rawDelta = placement.center - object.placement.center
                    guides = [SnapGuide(start: host.start, end: host.end, kind: .wallFace)]
                }
            } else if !isOptionDown {
                let targetCenter = object.placement.center + rawDelta
                let snap = Snapper.snap(
                    point: targetCenter,
                    layout: context.layout,
                    pointsPerMetre: event.pointsPerMetre,
                    isFree: false,
                    ignoringObjectID: candidateID
                )
                rawDelta = snap.point - object.placement.center
                guides = snap.guides
            }
        }

        activeDragDeltaWorld = rawDelta
        context.setPreview(CanvasDragState(
            objectID: activeDragObjectID,
            deltaWorld: rawDelta,
            pointerLocation: event.viewPoint,
            isOptionDown: isOptionDown,
            guides: guides
        ))
    }

    private func finishResize(_ resize: ActiveResize, context: ToolContext) {
        if let current = context.layout.objects.first(where: { $0.id == resize.objectID }),
           current.kind.isResizable {
            var updated = current
            updated.placement = resize.preview
            context.applyEdit(.replace(before: current, after: updated), coalesceKey: "resize-\(resize.objectID)")
        }
        resetGesture()
        context.clearPreview()
    }

    private func finishCandidate(event: CanvasPointerEvent, candidateID: UUID, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        if SelectGesture.isPastThreshold(translation) {
            commitObjectDrag(candidateID: candidateID, freeMove: event.modifiers.contains(.option), context: context)
        } else if event.modifiers.contains(.shift) {
            context.toggleSelection(candidateID)
        } else {
            context.selectObject(candidateID)
        }
        resetGesture()
        context.clearPreview()
    }

    private func commitObjectDrag(candidateID: UUID, freeMove: Bool, context: ToolContext) {
        guard let before = context.layout.objects.first(where: { $0.id == candidateID }),
              before.kind.isMovable,
              simd_length(activeDragDeltaWorld) > 1e-4 else {
            return
        }
        if before.kind == .door {
            commitDoorDrag(before: before, context: context)
            return
        }
        var after = before
        after.placement.center += activeDragDeltaWorld
        guard after != before else { return }
        context.applyEdit(.replace(before: before, after: after), coalesceKey: "drag-\(candidateID)")
    }

    private func commitDoorDrag(before: LayoutObject, context: ToolContext) {
        guard let host = DoorHosting.nearestHost(to: before.placement.center, in: context.layout, reach: 0.3),
              let newPlacement = DoorHosting.placement(
                  width: before.placement.sizeM.x,
                  on: host,
                  near: before.placement.center + activeDragDeltaWorld
              ) else {
            return
        }
        var after = before
        after.placement = newPlacement
        after.doorFlow?.connection = DoorHosting.connection(for: newPlacement.center, on: host, in: context.layout)
        guard after != before else { return }
        context.applyEdit(.replace(before: before, after: after), coalesceKey: "drag-\(before.id)")
    }

    private func finishMarquee(
        event: CanvasPointerEvent,
        start: SIMD2<Double>,
        current: SIMD2<Double>,
        context: ToolContext
    ) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        if SelectGesture.isPastThreshold(translation) {
            let touched = SelectGesture.touchedObjects(
                from: start,
                to: current,
                layout: context.layout,
                layer: context.activeLayer
            )
            context.selectBooths(touched, additive: event.modifiers.contains(.shift))
        } else {
            if let locked = LayoutHitTester.lockedObject(
                at: event.worldPoint,
                in: context.layout,
                currentLayer: context.activeLayer
            ) {
                let name = locked.kind == .wall ? "Walls" : "\(locked.kind.displayName)s"
                context.showTransientHint("\(name) are locked on this layer")
            }
            context.selectObject(nil)
        }
        resetGesture()
        context.clearPreview()
    }
}

import CoreGraphics
import Foundation
import simd

struct ActiveNodeDrag: Sendable {
    let nodeID: UUID
    let initialPosition: SIMD2<Double>
    let targetWallID: UUID?
    let isDetach: Bool
    let initialGraph: WallGraph
}

extension SelectTool {
    func updateNodeDrag(
        event: CanvasPointerEvent,
        nodeDrag: ActiveNodeDrag,
        context: ToolContext
    ) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        guard SelectGesture.isPastThreshold(translation) else { return }

        let isOptionDown = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isOptionDown
        )
        let newPosition = snapResult.point
        let edit: LayoutEdit
        if nodeDrag.isDetach, let targetWallID = nodeDrag.targetWallID {
            edit = WallEditing.detach(
                wallID: targetWallID,
                at: nodeDrag.nodeID,
                to: newPosition,
                in: context.layout,
                graph: nodeDrag.initialGraph
            )
        } else {
            edit = WallEditing.moveNode(
                nodeID: nodeDrag.nodeID,
                to: newPosition,
                in: context.layout,
                graph: nodeDrag.initialGraph
            )
        }

        var previewPlacements: [UUID: Placement] = [:]
        if case .batch(let edits) = edit {
            for subEdit in edits {
                if case .replace(_, let after) = subEdit {
                    previewPlacements[after.id] = after.placement
                }
            }
        }

        context.setPreview(CanvasDragState(
            pointerLocation: event.viewPoint,
            isOptionDown: isOptionDown,
            previewPlacements: previewPlacements,
            guides: snapResult.guides
        ))
    }

    func finishNodeDrag(
        event: CanvasPointerEvent,
        nodeDrag: ActiveNodeDrag,
        context: ToolContext
    ) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        if SelectGesture.isPastThreshold(translation) {
            let isOptionDown = event.modifiers.contains(.option)
            let snapResult = Snapper.snap(
                point: event.worldPoint,
                layout: context.layout,
                pointsPerMetre: event.pointsPerMetre,
                isFree: isOptionDown
            )
            let newPosition = snapResult.point
            let edit: LayoutEdit
            if nodeDrag.isDetach, let targetWallID = nodeDrag.targetWallID {
                edit = WallEditing.detach(
                    wallID: targetWallID,
                    at: nodeDrag.nodeID,
                    to: newPosition,
                    in: context.layout,
                    graph: nodeDrag.initialGraph
                )
            } else {
                edit = WallEditing.moveNode(
                    nodeID: nodeDrag.nodeID,
                    to: newPosition,
                    in: context.layout,
                    graph: nodeDrag.initialGraph
                )
            }
            context.applyEdit(edit)
        } else if let targetWallID = nodeDrag.targetWallID {
            context.selectObject(targetWallID)
        }
        activeNodeDrag = nil
        resetGesture()
        context.clearPreview()
    }
}

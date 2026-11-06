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

struct ActiveMidpointDrag: Sendable {
    let wall: LayoutObject
    let initialCenter: SIMD2<Double>
}

extension SelectTool {
    func handleStructurePress(_ event: CanvasPointerEvent, context: ToolContext) -> Bool {
        guard context.activeLayer == .structure else { return false }
        let hitTolerance = Snapper.tolerance(pointsPerMetre: event.pointsPerMetre)
        let graph = WallGraph(layout: context.layout)

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
            return true
        }

        if let selectedID = context.selectionID,
           let selectedWall = context.layout.objects.first(where: { $0.id == selectedID && $0.kind == .wall }),
           simd_distance(event.worldPoint, selectedWall.placement.center) <= hitTolerance {
            activeMidpointDrag = ActiveMidpointDrag(
                wall: selectedWall,
                initialCenter: selectedWall.placement.center
            )
            return true
        }

        if let edge = HallEdges.edge(near: event.worldPoint, in: context.layout.hall, within: hitTolerance) {
            activeHallEdge = edge
            return true
        }

        return false
    }

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

        let draggedLength = nodeDrag.targetWallID.flatMap { previewPlacements[$0] }?.sizeM.x
        context.setPreview(CanvasDragState(
            pointerLocation: event.viewPoint,
            isOptionDown: isOptionDown,
            previewPlacements: previewPlacements,
            guides: snapResult.guides,
            wallLengthChipText: draggedLength.map { "\(DimensionInput.text(for: $0)) m" },
            wallLengthChipWorld: draggedLength == nil ? nil : newPosition
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

    func updateMidpointDrag(
        event: CanvasPointerEvent,
        midpointDrag: ActiveMidpointDrag,
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
        let edit = WallEditing.bendMidpoint(
            wall: midpointDrag.wall,
            to: newPosition,
            in: context.layout
        )

        var previewPlacements: [UUID: Placement] = [:]
        var previewInserts: [LayoutObject] = []
        if case .batch(let edits) = edit {
            for subEdit in edits {
                switch subEdit {
                case .replace(_, let after):
                    previewPlacements[after.id] = after.placement
                case .insert(let inserted, _):
                    previewInserts.append(inserted)
                default:
                    break
                }
            }
        }

        context.setPreview(CanvasDragState(
            pointerLocation: event.viewPoint,
            isOptionDown: isOptionDown,
            previewPlacements: previewPlacements,
            previewInserts: previewInserts,
            guides: snapResult.guides
        ))
    }

    func finishMidpointDrag(
        event: CanvasPointerEvent,
        midpointDrag: ActiveMidpointDrag,
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
            let edit = WallEditing.bendMidpoint(
                wall: midpointDrag.wall,
                to: newPosition,
                in: context.layout
            )
            context.applyEdit(edit)
        }
        activeMidpointDrag = nil
        resetGesture()
        context.clearPreview()
    }

    func wallDragPreview(
        wall: LayoutObject,
        rawDelta: SIMD2<Double>,
        context: ToolContext
    ) -> [UUID: Placement] {
        let graph = WallGraph(layout: context.layout)
        let edit = WallEditing.moveWallWithNeighbours(
            wall: wall,
            delta: rawDelta,
            in: context.layout,
            graph: graph
        )
        var previewPlacements: [UUID: Placement] = [:]
        if case .batch(let edits) = edit {
            for subEdit in edits {
                if case .replace(_, let after) = subEdit {
                    previewPlacements[after.id] = after.placement
                }
            }
        }
        return previewPlacements
    }

    func commitWallDrag(
        before: LayoutObject,
        candidateID: UUID,
        delta: SIMD2<Double>,
        context: ToolContext
    ) {
        let graph = WallGraph(layout: context.layout)
        let edit = WallEditing.moveWallWithNeighbours(
            wall: before,
            delta: delta,
            in: context.layout,
            graph: graph
        )
        context.applyEdit(edit, coalesceKey: "drag-\(candidateID)")
    }

    func computeCandidateSnapDelta(
        candidateID: UUID,
        rawDelta: SIMD2<Double>,
        isOptionDown: Bool,
        event: CanvasPointerEvent,
        context: ToolContext
    ) -> (delta: SIMD2<Double>, guides: [SnapGuide]) {
        guard let object = context.layout.objects.first(where: { $0.id == candidateID }), !isOptionDown else {
            return (rawDelta, [])
        }
        if object.kind == .door {
            let reach = Snapper.tolerance(pointsPerMetre: event.pointsPerMetre)
            if let host = DoorHosting.nearestHost(to: object.placement.center, in: context.layout, reach: reach),
               let placement = DoorHosting.placement(
                   width: object.placement.sizeM.x,
                   on: host,
                   near: object.placement.center + rawDelta
               ) {
                let guides = [SnapGuide(start: host.start, end: host.end, kind: .wallFace)]
                return (placement.center - object.placement.center, guides)
            }
            return (rawDelta, [])
        }
        let targetCenter = object.placement.center + rawDelta
        let snap = Snapper.snap(
            point: targetCenter,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: false,
            ignoringObjectID: candidateID
        )
        return (snap.point - object.placement.center, snap.guides)
    }
}

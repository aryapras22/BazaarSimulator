import Foundation
import simd

@MainActor
final class WallTool: EditorToolHandling {
    let itemID: String
    var tool: EditorTool { .drawWall(itemID: itemID) }

    private(set) var drawing: WallDrawing?
    private(set) var currentPointer: SIMD2<Double>?
    private var lastPointerEvent: CanvasPointerEvent?

    init(itemID: String) {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        lastPointerEvent = event
        let isShiftDown = event.modifiers.contains(.shift)
        let isFree = event.modifiers.contains(.option)
        let snapResult = WallDrawing.snap(
            event.worldPoint,
            from: drawing?.points.last,
            in: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            lockAngle: isShiftDown,
            isFree: isFree
        )
        let snapped = currentPointer ?? snapResult.point

        let reachM = max(Snapper.tolerance(pointsPerMetre: event.pointsPerMetre), 0.3)
        if let first = drawing?.points.first,
           (drawing?.points.count ?? 0) >= 3,
           simd_distance(snapped, first) <= reachM {
            drawing?.points.append(first)
            finish(context: context)
            return
        }

        if drawing == nil || drawing?.points.isEmpty == true {
            drawing = WallDrawing(points: [snapped], typedLength: "")
        } else if let last = drawing?.points.last, last != snapped {
            drawing?.points.append(snapped)
            drawing?.typedLength = ""
        }
        currentPointer = snapped
        updatePreview(context: context, lockAngle: isShiftDown, guides: snapResult.guides)
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        lastPointerEvent = event
        let isShiftDown = event.modifiers.contains(.shift)
        let isFree = event.modifiers.contains(.option)

        let reachM = max(Snapper.tolerance(pointsPerMetre: event.pointsPerMetre), 0.3)
        if let first = drawing?.points.first,
           (drawing?.points.count ?? 0) >= 3,
           simd_distance(event.worldPoint, first) <= reachM {
            currentPointer = first
            updatePreview(context: context, lockAngle: false, guides: [])
            return
        }

        let snapResult = WallDrawing.snap(
            event.worldPoint,
            from: drawing?.points.last,
            in: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            lockAngle: isShiftDown,
            isFree: isFree
        )
        let snapped = snapResult.point

        if let typed = drawing?.typedLength,
           let length = Double(typed) {
            if let last = drawing?.points.last {
                currentPointer = WallDrawing.point(from: last, toward: snapped, length: length)
            } else if let wallPoint = WallEditing.pointOnHostWall(
                snapped: snapped,
                distanceFromNearEnd: length,
                in: context.layout,
                tolerance: max(Snapper.tolerance(pointsPerMetre: event.pointsPerMetre), 0.1)
            ) {
                currentPointer = wallPoint
            } else {
                currentPointer = snapped
            }
        } else {
            currentPointer = snapped
        }
        updatePreview(context: context, lockAngle: isShiftDown, guides: snapResult.guides)
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {}

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {
        finish(context: context)
    }

    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        switch key {
        case .character(let char):
            guard char.isNumber || char == "." else { return false }
            if drawing == nil {
                drawing = WallDrawing(points: [], typedLength: String(char))
            } else {
                drawing?.typedLength.append(char)
            }
            recomputePointer(context: context)
            return true

        case .delete:
            return handleDelete(context: context)

        case .returnKey:
            return handleReturn(context: context)

        case .escape:
            if drawing?.points.isEmpty == false {
                stepBack(context: context)
            } else {
                cancel(context: context)
            }
            return true

        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        drawing = nil
        currentPointer = nil
        context.clearPreview()
        context.switchTool(.select)
    }

    private func stepBack(context: ToolContext) {
        drawing?.typedLength = ""
        drawing?.points.removeLast()
        if drawing?.points.isEmpty == true {
            drawing = nil
            currentPointer = nil
            context.clearPreview()
        } else {
            recomputePointer(context: context)
        }
    }

    private func handleDelete(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength, !typed.isEmpty {
            drawing?.typedLength.removeLast()
            recomputePointer(context: context)
            return true
        }
        if let points = drawing?.points, !points.isEmpty {
            drawing?.points.removeLast()
            if drawing?.points.isEmpty == true {
                drawing = nil
                context.clearPreview()
            } else {
                recomputePointer(context: context)
            }
            return true
        }
        return false
    }

    private func handleReturn(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength,
           let length = Double(typed) {
            if let last = drawing?.points.last, let pointer = currentPointer {
                let nextPoint = WallDrawing.point(from: last, toward: pointer, length: length)
                drawing?.points.append(nextPoint)
                drawing?.typedLength = ""
                recomputePointer(context: context)
                return true
            } else if let pointer = currentPointer, drawing?.points.isEmpty ?? true {
                drawing = WallDrawing(points: [pointer], typedLength: "")
                recomputePointer(context: context)
                return true
            }
        }
        if let points = drawing?.points, points.count >= 2 {
            finish(context: context)
            return true
        }
        return false
    }

    private func recomputePointer(context: ToolContext) {
        guard let lastEvent = lastPointerEvent else {
            updatePreview(context: context, lockAngle: false)
            return
        }
        let isShiftDown = lastEvent.modifiers.contains(.shift)
        let isFree = lastEvent.modifiers.contains(.option)
        let snapResult = WallDrawing.snap(
            lastEvent.worldPoint,
            from: drawing?.points.last,
            in: context.layout,
            pointsPerMetre: lastEvent.pointsPerMetre,
            lockAngle: isShiftDown,
            isFree: isFree
        )
        let snapped = snapResult.point

        if let typed = drawing?.typedLength, let length = Double(typed) {
            if let last = drawing?.points.last {
                currentPointer = WallDrawing.point(from: last, toward: snapped, length: length)
            } else if let wallPoint = WallEditing.pointOnHostWall(
                snapped: snapped,
                distanceFromNearEnd: length,
                in: context.layout,
                tolerance: max(Snapper.tolerance(pointsPerMetre: lastEvent.pointsPerMetre), 0.1)
            ) {
                currentPointer = wallPoint
            } else {
                currentPointer = snapped
            }
        } else {
            currentPointer = snapped
        }
        updatePreview(context: context, lockAngle: isShiftDown, guides: snapResult.guides)
    }

    private func updatePreview(context: ToolContext, lockAngle: Bool, guides: [SnapGuide] = []) {
        context.setPreview(CanvasDragState(
            isShiftDown: lockAngle,
            wallDrawing: drawing,
            wallCurrentPointer: currentPointer,
            guides: guides
        ))
    }

    private func finish(context: ToolContext) {
        guard let drawing, drawing.points.count >= 2 else {
            cancel(context: context)
            return
        }

        let item = ObjectCatalog.item(itemID)
        let thickness = item?.sizeM.y ?? 0.2
        let height = item?.heightM ?? 3.0
        let kind = item?.kind ?? .wall
        let attributes = WallEditing.WallAttributes(
            kind: kind,
            thickness: thickness,
            height: height,
            catalogID: itemID
        )

        let plan = WallEditing.planChainCommit(
            points: drawing.points,
            attributes: attributes,
            in: context.layout
        )

        context.applyEdit(plan.edit)
        if let lastID = plan.createdWallIDs.last {
            context.selectObject(lastID)
        }

        self.drawing = nil
        self.currentPointer = nil
        context.clearPreview()
        context.switchTool(.select)
    }
}

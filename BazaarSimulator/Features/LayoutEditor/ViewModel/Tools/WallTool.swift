import Foundation
import simd

@MainActor
final class WallTool: EditorToolHandling {
    let itemID: String
    var tool: EditorTool { .drawWall(itemID: itemID) }

    private(set) var drawing: WallDrawing?
    private(set) var currentPointer: SIMD2<Double>?

    init(itemID: String) {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
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
        let snapped = snapResult.point

        if drawing == nil {
            drawing = WallDrawing(points: [snapped], typedLength: "")
        } else if let last = drawing?.points.last, last != snapped {
            drawing?.points.append(snapped)
            drawing?.typedLength = ""
        }
        currentPointer = snapped
        updatePreview(context: context, lockAngle: isShiftDown, guides: snapResult.guides)
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
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
        let snapped = snapResult.point

        if let typed = drawing?.typedLength,
           let length = Double(typed),
           let last = drawing?.points.last {
            currentPointer = WallDrawing.point(from: last, toward: snapped, length: length)
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
            updatePreview(context: context, lockAngle: false)
            return true

        case .delete:
            return handleDelete(context: context)

        case .returnKey:
            return handleReturn(context: context)

        case .escape:
            cancel(context: context)
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

    private func handleDelete(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength, !typed.isEmpty {
            drawing?.typedLength.removeLast()
            updatePreview(context: context, lockAngle: false)
            return true
        }
        if let points = drawing?.points, !points.isEmpty {
            drawing?.points.removeLast()
            if drawing?.points.isEmpty == true {
                drawing = nil
                context.clearPreview()
            } else {
                updatePreview(context: context, lockAngle: false)
            }
            return true
        }
        return false
    }

    private func handleReturn(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength,
           let length = Double(typed),
           let last = drawing?.points.last,
           let pointer = currentPointer {
            let nextPoint = WallDrawing.point(from: last, toward: pointer, length: length)
            drawing?.points.append(nextPoint)
            drawing?.typedLength = ""
            updatePreview(context: context, lockAngle: false)
            return true
        }
        if let points = drawing?.points, points.count >= 2 {
            finish(context: context)
            return true
        }
        return false
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
        let newObjects = drawing.objects(
            kind: kind,
            thickness: thickness,
            height: height,
            catalogID: itemID
        )

        if !newObjects.isEmpty {
            let edits: [LayoutEdit] = newObjects.enumerated().map { index, object in
                .insert(object, index: context.layout.objects.count + index)
            }
            context.applyEdit(.batch(edits))
            if let lastID = newObjects.last?.id {
                context.selectObject(lastID)
            }
        }

        self.drawing = nil
        self.currentPointer = nil
        context.clearPreview()
        context.switchTool(.select)
    }
}

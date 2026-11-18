import Foundation
import simd

@MainActor
final class WallTool: EditorToolHandling {
    private struct PointerTarget {
        let point: SIMD2<Double>
        let guides: [SnapGuide]
        let isClosingLoop: Bool
    }

    let itemID: String
    var tool: EditorTool { .drawWall(itemID: itemID) }

    private(set) var drawing: WallDrawing?
    private(set) var currentPointer: SIMD2<Double>?
    private var lastPointerEvent: CanvasPointerEvent?
    private var chainStart: SIMD2<Double>?
    private var committedSegmentCount: Int = 0

    init(itemID: String) {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        lastPointerEvent = event
        let target = resolveTarget(for: event, in: context.layout)
        _ = advanceChain(to: target.point, isClosingLoop: target.isClosingLoop, in: context)
        if !target.isClosingLoop {
            updatePreview(
                context: context,
                lockAngle: event.modifiers.contains(.shift),
                guides: target.guides
            )
        }
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        lastPointerEvent = event
        let target = resolveTarget(for: event, in: context.layout)
        currentPointer = target.point
        updatePreview(
            context: context,
            lockAngle: !target.isClosingLoop && event.modifiers.contains(.shift),
            guides: target.guides
        )
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {}

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {
        endChain(context: context)
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
            cancel(context: context)
            return true

        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        endChain(context: context)
        context.switchTool(.select)
    }

    private func endChain(context: ToolContext) {
        drawing = nil
        chainStart = nil
        committedSegmentCount = 0
        currentPointer = nil
        context.clearPreview()
    }

    private func handleDelete(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength, !typed.isEmpty {
            drawing?.typedLength.removeLast()
            recomputePointer(context: context)
            return true
        }
        if drawing != nil {
            endChain(context: context)
            return true
        }
        return false
    }

    private func handleReturn(context: ToolContext) -> Bool {
        if let typed = drawing?.typedLength, let length = Double(typed) {
            if let last = drawing?.points.last, let pointer = currentPointer {
                let nextPoint = WallDrawing.point(from: last, toward: pointer, length: length)
                let closesLoop = committedSegmentCount >= 2
                    && chainStart.map { simd_distance(nextPoint, $0) < 1e-4 } == true
                _ = advanceChain(to: nextPoint, isClosingLoop: closesLoop, in: context)
                if !closesLoop {
                    recomputePointer(context: context)
                }
                return true
            }
            if let pointer = currentPointer, drawing?.points.isEmpty ?? true {
                _ = advanceChain(to: pointer, isClosingLoop: false, in: context)
                recomputePointer(context: context)
                return true
            }
        }
        if drawing != nil {
            endChain(context: context)
            return true
        }
        return false
    }

    private func advanceChain(to point: SIMD2<Double>, isClosingLoop: Bool, in context: ToolContext) -> Bool {
        if let last = drawing?.points.last {
            guard simd_distance(last, point) > 1e-6 else { return false }
            commitSegment(from: last, to: point, in: context)
            if isClosingLoop {
                endChain(context: context)
                return true
            }
            committedSegmentCount += 1
            drawing = WallDrawing(points: [point], previousPoint: last, typedLength: "")
            currentPointer = point
            return true
        }
        chainStart = point
        committedSegmentCount = 0
        drawing = WallDrawing(points: [point], typedLength: "")
        currentPointer = point
        return true
    }

    private func recomputePointer(context: ToolContext) {
        guard let lastEvent = lastPointerEvent else {
            updatePreview(context: context, lockAngle: false)
            return
        }
        let target = resolveTarget(for: lastEvent, in: context.layout)
        currentPointer = target.point
        updatePreview(
            context: context,
            lockAngle: !target.isClosingLoop && lastEvent.modifiers.contains(.shift),
            guides: target.guides
        )
    }

    private func resolveTarget(for event: CanvasPointerEvent, in layout: Layout) -> PointerTarget {
        let isShiftDown = event.modifiers.contains(.shift)
        let isFree = event.modifiers.contains(.option)
        let reachM = max(Snapper.tolerance(pointsPerMetre: event.pointsPerMetre), 0.3)

        if drawing?.typedLength.isEmpty ?? true,
           committedSegmentCount >= 2,
           let first = chainStart,
           simd_distance(event.worldPoint, first) <= reachM {
            return PointerTarget(point: first, guides: [], isClosingLoop: true)
        }

        let snapResult = WallDrawing.snap(
            event.worldPoint,
            from: drawing?.points.last,
            in: layout,
            pointsPerMetre: event.pointsPerMetre,
            lockAngle: isShiftDown,
            isFree: isFree
        )

        guard let typed = drawing?.typedLength, let length = Double(typed) else {
            return PointerTarget(point: snapResult.point, guides: snapResult.guides, isClosingLoop: false)
        }

        if let last = drawing?.points.last {
            let point = WallDrawing.point(from: last, toward: snapResult.point, length: length)
            let closesLoop = committedSegmentCount >= 2
                && chainStart.map { simd_distance(point, $0) < 1e-4 } == true
            return PointerTarget(point: point, guides: snapResult.guides, isClosingLoop: closesLoop)
        }

        if let wallPoint = WallEditing.pointOnHostWall(
            snapped: snapResult.point,
            distanceFromNearEnd: length,
            in: layout,
            tolerance: max(Snapper.tolerance(pointsPerMetre: event.pointsPerMetre), 0.1)
        ) {
            return PointerTarget(point: wallPoint, guides: snapResult.guides, isClosingLoop: false)
        }

        return PointerTarget(point: snapResult.point, guides: snapResult.guides, isClosingLoop: false)
    }

    private func updatePreview(context: ToolContext, lockAngle: Bool, guides: [SnapGuide] = []) {
        context.setPreview(CanvasDragState(
            isShiftDown: lockAngle,
            wallDrawing: drawing,
            wallCurrentPointer: currentPointer,
            guides: guides
        ))
    }

    private func commitSegment(from start: SIMD2<Double>, to end: SIMD2<Double>, in context: ToolContext) {
        let item = ObjectCatalog.item(itemID)
        let attributes = WallEditing.WallAttributes(
            kind: item?.kind ?? .wall,
            thickness: item?.sizeM.y ?? 0.2,
            height: item?.heightM ?? 3.0,
            catalogID: itemID
        )
        let plan = WallEditing.planChainCommit(
            points: [start, end],
            attributes: attributes,
            in: context.layout
        )
        context.applyEdit(plan.edit)
    }
}

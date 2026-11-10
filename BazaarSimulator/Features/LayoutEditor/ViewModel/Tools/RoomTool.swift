import Foundation
import simd

@MainActor
final class RoomTool: EditorToolHandling {
    let itemID: String
    var tool: EditorTool { .room(itemID: itemID) }

    private(set) var startWorld: SIMD2<Double>?
    private(set) var currentWorld: SIMD2<Double>?

    init(itemID: String) {
        self.itemID = itemID
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        startWorld = snapResult.point
        currentWorld = snapResult.point
        updatePreview(context: context, guides: snapResult.guides)
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let snapResult = Snapper.snap(
            point: event.worldPoint,
            layout: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            isFree: isFree
        )
        currentWorld = snapResult.point

        guard startWorld != nil else {
            context.setPreview(CanvasDragState(
                wallDrawing: WallDrawing(),
                wallCurrentPointer: snapResult.point,
                guides: snapResult.guides
            ))
            return
        }

        updatePreview(context: context, guides: snapResult.guides)
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        defer {
            startWorld = nil
            currentWorld = nil
            context.clearPreview()
            context.switchTool(.select)
        }

        guard let start = startWorld, let current = currentWorld else { return }
        let minX = min(start.x, current.x)
        let maxX = max(start.x, current.x)
        let minY = min(start.y, current.y)
        let maxY = max(start.y, current.y)

        guard (maxX - minX) >= 0.3, (maxY - minY) >= 0.3 else { return }

        let points = [
            SIMD2<Double>(minX, minY),
            SIMD2<Double>(maxX, minY),
            SIMD2<Double>(maxX, maxY),
            SIMD2<Double>(minX, maxY),
            SIMD2<Double>(minX, minY)
        ]

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
            points: points,
            attributes: attributes,
            in: context.layout
        )

        context.applyEdit(plan.edit)
        if let firstID = plan.createdWallIDs.first {
            context.selectObject(firstID)
        }
    }

    func handleDoubleClick(_ event: CanvasPointerEvent, context: ToolContext) {}

    func handleKey(_ key: CanvasKey, context: ToolContext) -> Bool {
        switch key {
        case .escape:
            cancel(context: context)
            return true
        default:
            return false
        }
    }

    func cancel(context: ToolContext) {
        startWorld = nil
        currentWorld = nil
        context.clearPreview()
        context.switchTool(.select)
    }

    private func updatePreview(context: ToolContext, guides: [SnapGuide] = []) {
        guard let start = startWorld, let current = currentWorld else { return }
        let minX = min(start.x, current.x)
        let maxX = max(start.x, current.x)
        let minY = min(start.y, current.y)
        let maxY = max(start.y, current.y)

        let points: [SIMD2<Double>]
        if (maxX - minX) >= 0.1 || (maxY - minY) >= 0.1 {
            points = [
                SIMD2<Double>(minX, minY),
                SIMD2<Double>(maxX, minY),
                SIMD2<Double>(maxX, maxY),
                SIMD2<Double>(minX, maxY),
                SIMD2<Double>(minX, minY)
            ]
        } else {
            points = [start, current]
        }

        context.setPreview(CanvasDragState(
            wallDrawing: WallDrawing(points: points),
            guides: guides
        ))
    }
}

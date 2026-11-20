import CoreGraphics
import Foundation
import simd

@MainActor
final class PlaceTool: EditorToolHandling {
    let source: LibraryRowDisplay.Source
    var rotationDegrees: Int
    var tool: EditorTool { .place(source) }

    private(set) var candidate: PlacementCandidate?
    private var pressViewPoint: CGPoint = .zero

    init(source: LibraryRowDisplay.Source, rotationDegrees: Int = 0) {
        self.source = source
        self.rotationDegrees = rotationDegrees
    }

    func handlePress(_ event: CanvasPointerEvent, context: ToolContext) {
        pressViewPoint = event.viewPoint
    }

    func handleMove(_ event: CanvasPointerEvent, context: ToolContext) {
        let isFree = event.modifiers.contains(.option)
        let (kind, size) = objectKindAndSize(source: source)
        let candidate = PlacementResolver.resolve(
            size: size,
            at: event.worldPoint,
            extraRotationDegrees: rotationDegrees,
            kind: kind,
            in: context.layout,
            pointsPerMetre: event.pointsPerMetre,
            free: isFree
        )
        self.candidate = candidate
        context.setPreview(CanvasDragState(
            placementCandidate: candidate,
            placingSource: source,
            guides: candidate.guides
        ))
    }

    func handleRelease(_ event: CanvasPointerEvent, context: ToolContext) {
        let translation = CGPoint(x: event.viewPoint.x - pressViewPoint.x, y: event.viewPoint.y - pressViewPoint.y)
        guard !SelectGesture.isPastThreshold(translation) || pressViewPoint == .zero else { return }

        if candidate == nil {
            handleMove(event, context: context)
        }
        guard let candidate, candidate.isValid else { return }
        commitCandidate(candidate, in: context)
        self.candidate = nil
        context.clearPreview()
        context.switchTool(.select)
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
        candidate = nil
        context.clearPreview()
        context.switchTool(.select)
    }

    private func objectKindAndSize(source: LibraryRowDisplay.Source) -> (LayoutObjectKind, SIMD2<Double>) {
        switch source {
        case .template(let template):
            return (.booth, SIMD2<Double>(template.sizeKey.shortM, template.sizeKey.longM))
        case .catalog(let itemID):
            let item = ObjectCatalog.item(itemID)
            return (item?.kind ?? .block, item?.sizeM ?? SIMD2<Double>(2, 2))
        }
    }

    private func commitCandidate(_ candidate: PlacementCandidate, in context: ToolContext) {
        switch source {
        case .template(let template):
            let objectID = UUID()
            let label = LayoutObjectNaming.nextLabel(for: .booth, in: context.layout)
            let booth = LayoutObject(
                id: objectID,
                kind: .booth,
                label: label,
                placement: candidate.placement,
                categoryID: template.categoryID,
                heightM: BoothShape.panelHeightM
            )
            context.applyEdit(.insert(booth, index: context.layout.objects.count))
            context.selectObject(objectID)

        case .catalog(let itemID):
            let item = ObjectCatalog.item(itemID)
            let kind = item?.kind ?? .block
            let label = LayoutObjectNaming.nextLabel(for: kind, in: context.layout)
            var placement = candidate.placement
            placement.shape = item?.placementShape ?? .rect
            let object = LayoutObject(
                id: UUID(),
                kind: kind,
                label: label,
                placement: placement,
                catalogID: itemID,
                heightM: item?.heightM
            )
            context.applyEdit(.insert(object, index: context.layout.objects.count))
            context.selectObject(object.id)
        }
    }
}

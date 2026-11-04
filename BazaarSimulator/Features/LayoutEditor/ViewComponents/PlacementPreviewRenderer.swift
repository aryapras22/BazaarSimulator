import SwiftUI
import simd

enum PlacementPreviewRenderer {
    static func draw(
        candidate: PlacementCandidate,
        source: LibraryRowDisplay.Source,
        legend: Legend,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        var previewContext = context
        previewContext.opacity = 0.5

        switch source {
        case .template(let template):
            drawTemplatePreview(
                candidate: candidate,
                template: template,
                legend: legend,
                in: &previewContext,
                transform: transform
            )
        case .catalog(let itemID):
            drawCatalogPreview(
                candidate: candidate,
                itemID: itemID,
                in: &previewContext,
                transform: transform
            )
        }

        if !candidate.isValid {
            let corners = LayoutGeometry.corners(of: candidate.placement)
            let path = FloorRenderer.polygonPath(for: corners, transform: transform)
            context.stroke(path, with: .color(Palette.canvasIssue), lineWidth: 2.5)
        }

        drawSizeChip(candidate: candidate, in: &context, transform: transform)
    }

    private static func drawTemplatePreview(
        candidate: PlacementCandidate,
        template: BoothTemplate,
        legend: Legend,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let categoryColor = legend.entries.first { $0.id == template.categoryID }?.color
        let booth = LayoutObject(
            kind: .booth,
            label: "",
            placement: candidate.placement,
            categoryID: template.categoryID,
            openSides: [.bottom]
        )
        let state = BoothDrawState(
            booth: booth,
            displayLabel: "",
            tab: .floorPlan,
            isSelected: false,
            isHovered: false,
            isGroupMember: false,
            isHoveredGroupMember: false,
            hasObjectWarning: !candidate.isValid,
            blockedSides: [],
            categoryColor: categoryColor
        )
        BoothRenderer.draw(state, in: &context, transform: transform)
    }

    private static func drawCatalogPreview(
        candidate: PlacementCandidate,
        itemID: String,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let item = ObjectCatalog.item(itemID)
        let placement = candidate.placement
        let outlineColor = candidate.isValid ? Palette.canvasLine : Palette.canvasIssue
        let outlineWidth: CGFloat = candidate.isValid ? 1.5 : 2.0

        if item?.footprint == .circle {
            let centerView = transform.toView(placement.center)
            let radius = CGFloat(placement.sizeM.x / 2.0 * transform.scale)
            let circleRect = CGRect(
                x: CGFloat(centerView.x) - radius,
                y: CGFloat(centerView.y) - radius,
                width: radius * 2.0,
                height: radius * 2.0
            )
            let circlePath = Path(ellipseIn: circleRect)
            context.fill(circlePath, with: .color(Palette.canvasLineGlow))
            context.stroke(circlePath, with: .color(outlineColor), lineWidth: outlineWidth)
        } else {
            let corners = LayoutGeometry.corners(of: placement)
            let path = FloorRenderer.polygonPath(for: corners, transform: transform)
            context.fill(path, with: .color(Palette.canvasLineGlow))
            context.stroke(path, with: .color(outlineColor), lineWidth: outlineWidth)
        }
    }

    private static func drawSizeChip(
        candidate: PlacementCandidate,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let centerView = transform.toView(candidate.placement.center)
        let chipLocation = CGPoint(x: CGFloat(centerView.x) + 12.0, y: CGFloat(centerView.y) + 12.0)
        let widthText = DimensionInput.text(for: candidate.placement.sizeM.x)
        let lengthText = DimensionInput.text(for: candidate.placement.sizeM.y)
        let sizeText: String
        if let note = candidate.note {
            sizeText = "\(widthText) × \(lengthText) m · \(note)"
        } else {
            sizeText = "\(widthText) × \(lengthText) m"
        }
        SelectionDimensionRenderer.drawSizeChip(sizeText, near: chipLocation, in: &context)
    }
}

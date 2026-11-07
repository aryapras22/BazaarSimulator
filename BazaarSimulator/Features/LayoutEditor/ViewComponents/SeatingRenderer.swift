import SwiftUI
import simd

/// Draws a table or a seating block with the chairs its standard model puts around it.
enum SeatingRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let object = state.object
        let strokeColor = state.hasWarning ? Palette.canvasIssue : Palette.canvasLine
        let chairFill = state.isSelected ? Palette.canvasSelection : Palette.canvasLine.opacity(0.08)

        if object.kind == .seating {
            let corners = LayoutGeometry.corners(of: object.placement)
            let extent = FloorRenderer.polygonPath(for: corners, transform: transform)
            context.stroke(extent, with: .color(strokeColor.opacity(state.isSelected ? 0.9 : 0.3)), lineWidth: 1)
        }

        for chair in FurnitureModels.chairs(of: object) {
            let path = FloorRenderer.polygonPath(for: LayoutGeometry.corners(of: chair), transform: transform)
            context.fill(path, with: .color(chairFill))
            context.stroke(path, with: .color(strokeColor.opacity(0.7)), lineWidth: 0.8)
        }

        guard object.kind == .table else { return }
        let top = tablePath(of: object, transform: transform)
        context.fill(top, with: .color(state.isSelected ? Palette.canvasSelection : Palette.canvasLine.opacity(0.2)))
        context.stroke(top, with: .color(strokeColor), lineWidth: state.hasWarning ? 2.0 : 1.2)
        if state.isHovered && !state.isSelected {
            context.stroke(top, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }
    }

    private static func tablePath(of table: LayoutObject, transform: CanvasTransform) -> Path {
        let isRound = FurnitureModels.table(table.catalogID)?.shape == .round
        guard isRound else {
            return FloorRenderer.polygonPath(for: LayoutGeometry.corners(of: table.placement), transform: transform)
        }
        let centre = transform.toView(table.placement.center)
        let radius = table.placement.sizeM.x / 2 * transform.scale
        let bounds = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
        return Path(ellipseIn: bounds)
    }
}

import SwiftUI
import simd

struct ObjectDrawState: Sendable {
    let object: LayoutObject
    let isSelected: Bool
    let isHovered: Bool
    let hasWarning: Bool
    var cornerExtensions: (start: Double, end: Double) = (0.0, 0.0)
}

@MainActor
enum SeatingRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let table = state.object
        let isRound = table.catalogID.flatMap(ObjectCatalog.item)?.footprint == .circle

        let fillColor: Color
        let strokeColor: Color
        if state.isSelected {
            fillColor = Palette.canvasSelection
            strokeColor = Palette.canvasLine
        } else {
            fillColor = Palette.canvasBoothFill
            strokeColor = Palette.canvasLine
        }

        let tablePath: Path
        if isRound {
            tablePath = drawChairsAroundRoundTable(
                table,
                fillColor: fillColor,
                strokeColor: strokeColor,
                in: &context,
                transform: transform
            )
        } else {
            let corners = LayoutGeometry.corners(of: table.placement).map { transform.toView($0) }
            var path = Path()
            path.addLines(corners.map { CGPoint(x: $0.x, y: $0.y) })
            path.closeSubpath()
            tablePath = path

            if let catalogID = table.catalogID, catalogID == "table-2" || catalogID == "table-4" {
                let chairCount = catalogID == "table-2" ? 2 : 4
                drawRectangularTableChairs(
                    for: table,
                    count: chairCount,
                    colors: (fillColor, strokeColor),
                    in: &context,
                    transform: transform
                )
            }
        }

        context.fill(tablePath, with: .color(fillColor))
        let outlineColor = state.hasWarning ? Palette.canvasIssue : strokeColor
        context.stroke(tablePath, with: .color(outlineColor), lineWidth: state.hasWarning ? 2.0 : 1.0)

        if state.isHovered && !state.isSelected {
            context.stroke(tablePath, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }
    }

    /// Draws four chairs around a round table and returns the table top, sized to the shorter side of its placement.
    private static func drawChairsAroundRoundTable(
        _ table: LayoutObject,
        fillColor: Color,
        strokeColor: Color,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) -> Path {
        let centerView = transform.toView(table.placement.center)
        let radius = max(2.0, min(table.placement.sizeM.x, table.placement.sizeM.y) * 0.35 * transform.scale)
        let chairRadius = max(1.5, radius * 0.35)
        let chairDistance = radius + chairRadius * 1.1

        let angles: [Double] = [0, .pi / 2, .pi, 3 * .pi / 2]
        for angle in angles {
            let totalAngle = angle + table.placement.rotationRadians
            let chairX = centerView.x + cos(totalAngle) * chairDistance
            let chairY = centerView.y + sin(totalAngle) * chairDistance
            let chairRect = CGRect(
                x: chairX - chairRadius,
                y: chairY - chairRadius,
                width: chairRadius * 2,
                height: chairRadius * 2
            )
            let chairPath = Path(ellipseIn: chairRect)
            context.fill(chairPath, with: .color(fillColor))
            context.stroke(chairPath, with: .color(strokeColor), lineWidth: 0.8)
        }

        let tableRect = CGRect(
            x: centerView.x - radius,
            y: centerView.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        return Path(ellipseIn: tableRect)
    }

    private static func drawRectangularTableChairs(
        for table: LayoutObject,
        count: Int,
        colors: (fill: Color, stroke: Color),
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let chairs = TableChairs.chairPlacements(for: table.placement, count: count)
        for chair in chairs {
            let corners = LayoutGeometry.corners(of: chair).map { transform.toView($0) }
            var path = Path()
            path.addLines(corners.map { CGPoint(x: $0.x, y: $0.y) })
            path.closeSubpath()
            context.fill(path, with: .color(colors.fill))
            context.stroke(path, with: .color(colors.stroke), lineWidth: 0.8)
        }
    }
}

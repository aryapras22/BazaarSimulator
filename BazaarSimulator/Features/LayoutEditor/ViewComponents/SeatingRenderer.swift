import SwiftUI
import simd

struct ObjectDrawState: Sendable {
    let object: LayoutObject
    let tab: EditorTab
    let isSelected: Bool
    let isHovered: Bool
    let hasWarning: Bool
}

enum SeatingRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let table = state.object
        let centerView = transform.toView(table.placement.center)
        let radius = max(2.0, min(table.placement.sizeM.x, table.placement.sizeM.y) * 0.35 * transform.scale)
        let chairRadius = max(1.5, radius * 0.35)
        let chairDistance = radius + chairRadius * 1.1

        let fillColor: Color
        let strokeColor: Color
        if state.tab == .flow {
            fillColor = Palette.canvasFlowFill
            strokeColor = Palette.canvasFlowLine
        } else if state.isSelected {
            fillColor = Palette.canvasSelection
            strokeColor = Palette.canvasLine
        } else {
            fillColor = Palette.canvasBoothFill
            strokeColor = Palette.canvasLine
        }

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
        let tablePath = Path(ellipseIn: tableRect)
        context.fill(tablePath, with: .color(fillColor))
        let outlineColor = state.hasWarning ? Palette.canvasIssue : strokeColor
        context.stroke(tablePath, with: .color(outlineColor), lineWidth: state.hasWarning ? 2.0 : 1.0)

        if state.isHovered && !state.isSelected {
            context.stroke(tablePath, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }
    }
}

import SwiftUI
import simd

struct ObjectDrawState: Sendable {
    let object: LayoutObject
    let isSelected: Bool
    let isHovered: Bool
    let hasWarning: Bool
    var cornerExtensions: (start: Double, end: Double) = (0.0, 0.0)
}

enum ObstacleRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let object = state.object
        let corners: [SIMD2<Double>]
        if object.kind == .wall, state.cornerExtensions.start > 0 || state.cornerExtensions.end > 0 {
            corners = WallCornerExtensions.extendedCorners(for: object, extensions: state.cornerExtensions)
        } else {
            corners = LayoutGeometry.outline(of: object.placement)
        }
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let fillColor: Color
        let strokeColor: Color
        if state.isSelected {
            fillColor = Palette.canvasSelection
            strokeColor = Palette.canvasLine
        } else if object.kind == .wall {
            fillColor = Palette.canvasLine
            strokeColor = Palette.canvasLine
        } else if object.kind == .block {
            fillColor = Palette.canvasLine.opacity(0.25)
            strokeColor = Palette.canvasLine
        } else {
            fillColor = Palette.canvasLineGlow
            strokeColor = Palette.canvasLine
        }

        context.fill(path, with: .color(fillColor))
        let outlineColor = state.hasWarning ? Palette.canvasIssue : strokeColor
        context.stroke(path, with: .color(outlineColor), lineWidth: state.hasWarning ? 2.0 : 1.2)

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        if transform.scale >= 10.0, object.kind == .block, !object.isColumn {
            let centerView = transform.toView(object.placement.center)
            let labelColor = state.isSelected ? Color.white : strokeColor
            let text = Text(object.label)
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(labelColor)
            context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
        }
    }
}

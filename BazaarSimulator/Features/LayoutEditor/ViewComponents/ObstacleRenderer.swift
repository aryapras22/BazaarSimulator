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
        let isDisabled = DisabledObjectIndicator.isDisabled(object)
        let corners: [SIMD2<Double>]
        if object.kind == .wall, state.cornerExtensions.start > 0 || state.cornerExtensions.end > 0 {
            corners = WallCornerExtensions.extendedCorners(for: object, extensions: state.cornerExtensions)
        } else {
            corners = LayoutGeometry.outline(of: object.placement)
        }
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let fillColor = fill(for: state, isDisabled: isDisabled)
        let strokeColor = Palette.canvasLine

        context.fill(path, with: .color(fillColor))
        let outlineColor = state.hasWarning ? Palette.canvasIssue : strokeColor
        context.stroke(path, with: .color(outlineColor), lineWidth: state.hasWarning ? 2.0 : 1.2)

        if isDisabled {
            DisabledObjectIndicator.drawOverlay(
                for: object.placement,
                isSelected: state.isSelected,
                in: &context,
                transform: transform
            )
        }

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        drawLabel(
            for: state,
            isDisabled: isDisabled,
            strokeColor: strokeColor,
            in: &context,
            transform: transform
        )
    }

    private static func fill(for state: ObjectDrawState, isDisabled: Bool) -> Color {
        if state.isSelected {
            return Palette.canvasSelection
        }
        if isDisabled {
            return DisabledObjectIndicator.mutedFill
        }
        if state.object.kind == .wall {
            return Palette.canvasLine
        }
        if state.object.kind == .block {
            return Palette.canvasLine.opacity(0.25)
        }
        return Palette.canvasLineGlow
    }

    private static func drawLabel(
        for state: ObjectDrawState,
        isDisabled: Bool,
        strokeColor: Color,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= 10.0 else { return }
        let object = state.object
        let labelText: String
        if isDisabled {
            labelText = DisabledObjectIndicator.displayLabel(for: object)
        } else if object.kind == .block, !object.isColumn {
            labelText = object.label
        } else {
            return
        }
        let centerView = transform.toView(object.placement.center)
        let labelColor = state.isSelected ? Color.white : strokeColor
        let text = Text(labelText)
            .font(Typography.canvasLabel(scaledBy: transform.scale))
            .foregroundStyle(labelColor)
        context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
    }
}

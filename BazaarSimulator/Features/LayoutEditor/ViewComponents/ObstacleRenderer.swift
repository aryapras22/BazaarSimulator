import SwiftUI
import simd

enum ObstacleRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let object = state.object
        if object.kind == .pillar {
            drawPillar(state, in: &context, transform: transform)
            return
        }

        let corners = LayoutGeometry.corners(of: object.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let fillColor: Color
        let strokeColor: Color
        if state.isSelected {
            fillColor = Palette.canvasSelection
            strokeColor = Palette.canvasLine
        } else if object.kind == .wall || object.kind == .rail || object.kind == .block {
            fillColor = Palette.canvasLine.opacity(0.25)
            strokeColor = Palette.canvasLine
        } else {
            fillColor = Palette.canvasLineGlow
            strokeColor = Palette.canvasLine
        }

        context.fill(path, with: .color(fillColor))
        let outlineColor = state.hasWarning ? Palette.canvasIssue : strokeColor
        context.stroke(path, with: .color(outlineColor), lineWidth: state.hasWarning ? 2.0 : 1.2)

        if object.kind == .stage {
            drawStageFront(object: object, in: &context, transform: transform)
        }

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        if transform.scale >= 10.0, shouldDrawLabel(for: object.kind) {
            let centerView = transform.toView(object.placement.center)
            let labelColor = state.isSelected ? Color.white : strokeColor
            let text = Text(object.label)
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(labelColor)
            context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
        }
    }

    private static func shouldDrawLabel(for kind: LayoutObjectKind) -> Bool {
        switch kind {
        case .fixture, .stage, .audienceArea: return true
        default: return false
        }
    }

    private static func drawPillar(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let object = state.object
        let centerView = transform.toView(object.placement.center)
        let radius = max(2.0, (object.placement.sizeM.x / 2.0) * transform.scale)
        let rect = CGRect(x: centerView.x - radius, y: centerView.y - radius, width: radius * 2, height: radius * 2)
        let path = Path(ellipseIn: rect)
        let fill = state.isSelected ? Palette.canvasSelection : Palette.canvasLine
        context.fill(path, with: .color(fill))
        if state.hasWarning {
            context.stroke(path, with: .color(Palette.canvasIssue), lineWidth: 2.0)
        } else if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }
    }

    private static func drawStageFront(
        object: LayoutObject,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: object.placement)
        guard corners.count == 4 else { return }
        let edgeIndices: (Int, Int)?
        if object.openSides.contains(.top) {
            edgeIndices = (0, 1)
        } else if object.openSides.contains(.right) {
            edgeIndices = (1, 2)
        } else if object.openSides.contains(.bottom) {
            edgeIndices = (2, 3)
        } else if object.openSides.contains(.left) {
            edgeIndices = (3, 0)
        } else {
            edgeIndices = nil
        }

        guard let (startIdx, endIdx) = edgeIndices else { return }
        let startView = transform.toView(corners[startIdx])
        let endView = transform.toView(corners[endIdx])
        var frontPath = Path()
        frontPath.move(to: CGPoint(x: startView.x, y: startView.y))
        frontPath.addLine(to: CGPoint(x: endView.x, y: endView.y))
        context.stroke(frontPath, with: .color(Palette.highlight), lineWidth: 3.0)
    }
}

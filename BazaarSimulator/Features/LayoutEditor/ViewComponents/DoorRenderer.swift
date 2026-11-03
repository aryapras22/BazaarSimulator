import SwiftUI
import simd

enum DoorRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let door = state.object
        let corners = LayoutGeometry.corners(of: door.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        if state.tab == .floorPlan {
            context.fill(path, with: .color(Palette.canvasBoothFill))
            context.stroke(path, with: .color(Palette.canvasLine), lineWidth: 1.2)
            return
        }

        let direction = door.doorFlow?.direction ?? .both
        let fillColor: Color
        switch direction {
        case .entrance, .both:
            fillColor = state.isSelected ? Palette.canvasDoorLine : Palette.canvasDoorFill
        case .exit:
            fillColor = state.isSelected ? Palette.canvasDoorLine.opacity(0.85) : Palette.canvasFloor
        case .disabled:
            fillColor = Palette.diagramChip.opacity(0.45)
        }

        context.fill(path, with: .color(fillColor))

        let outlineColor = state.isSelected ? Palette.canvasDoorSelected : Palette.canvasDoorLine
        let lineWidth: CGFloat = state.isSelected ? 2.5 : 1.5
        if direction == .disabled {
            context.stroke(
                path,
                with: .color(Palette.diagramChip),
                style: StrokeStyle(lineWidth: lineWidth, dash: [4, 3])
            )
        } else {
            context.stroke(path, with: .color(outlineColor), lineWidth: lineWidth)
        }

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        drawDirectionArrows(direction: direction, placement: door.placement, in: &context, transform: transform)
    }

    private static func drawDirectionArrows(
        direction: DoorDirection,
        placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard direction != .disabled else { return }
        let arrowHalfLengthM = 0.65
        let inwardPoint = LayoutGeometry.toWorld(local: SIMD2<Double>(0, -arrowHalfLengthM), in: placement)
        let outwardPoint = LayoutGeometry.toWorld(local: SIMD2<Double>(0, arrowHalfLengthM), in: placement)
        let inwardView = transform.toView(inwardPoint)
        let outwardView = transform.toView(outwardPoint)

        var shaft = Path()
        shaft.move(to: CGPoint(x: outwardView.x, y: outwardView.y))
        shaft.addLine(to: CGPoint(x: inwardView.x, y: inwardView.y))
        context.stroke(shaft, with: .color(Palette.canvasDoorSelected), lineWidth: 1.5)

        if direction.allowsEntry {
            drawArrowHead(at: inwardView, from: outwardView, in: &context)
        }
        if direction.allowsExit {
            drawArrowHead(at: outwardView, from: inwardView, in: &context)
        }
    }

    private static func drawArrowHead(
        at tip: SIMD2<Double>,
        from tail: SIMD2<Double>,
        in context: inout GraphicsContext
    ) {
        let delta = tip - tail
        let length = simd_length(delta)
        guard length > 1e-3 else { return }
        let unit = delta / length
        let normal = SIMD2<Double>(-unit.y, unit.x)
        let headSize = 4.5
        let left = tip - unit * headSize + normal * (headSize * 0.65)
        let right = tip - unit * headSize - normal * (headSize * 0.65)

        var head = Path()
        head.move(to: CGPoint(x: left.x, y: left.y))
        head.addLine(to: CGPoint(x: tip.x, y: tip.y))
        head.addLine(to: CGPoint(x: right.x, y: right.y))
        context.stroke(head, with: .color(Palette.canvasDoorSelected), lineWidth: 1.5)
    }
}

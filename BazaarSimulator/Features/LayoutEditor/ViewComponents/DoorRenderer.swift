import SwiftUI
import simd

enum DoorRenderer {
    private static let doubleDoorThresholdM = 1.5
    private static let maxLeafLengthM = 1.5
    private static let arcSegmentCount = 16

    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let door = state.object
        let isDisabled = door.doorFlow?.direction == .disabled
        let fillColor = thresholdFill(for: state, isDisabled: isDisabled)
        let strokeColor = thresholdStroke(for: state, isDisabled: isDisabled)

        if !isDisabled {
            drawSwingArcs(
                for: door,
                colors: DoorColors(fill: fillColor, stroke: strokeColor),
                in: &context,
                transform: transform
            )
        }

        let corners = LayoutGeometry.corners(of: door.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)
        context.fill(path, with: .color(fillColor))
        let lineWidth: CGFloat = state.isSelected ? 2.2 : 1.5
        context.stroke(path, with: .color(strokeColor), lineWidth: lineWidth)

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        if isDisabled {
            drawDisabledCross(corners: corners, color: strokeColor, in: &context, transform: transform)
        }

        if transform.scale >= 10.0 {
            drawLabel(
                for: door,
                isSelected: state.isSelected,
                strokeColor: strokeColor,
                in: &context,
                transform: transform
            )
        }
    }

    private struct DoorColors {
        let fill: Color
        let stroke: Color
    }

    private static func thresholdFill(for state: ObjectDrawState, isDisabled: Bool) -> Color {
        if state.isSelected { return Palette.canvasSelection }
        if isDisabled { return Palette.canvasBoothFill }
        return Palette.canvasDoorFill
    }

    private static func thresholdStroke(for state: ObjectDrawState, isDisabled: Bool) -> Color {
        if state.hasWarning { return Palette.canvasIssue }
        if state.isSelected { return Palette.canvasDoorSelected }
        if isDisabled { return Palette.canvasFlowLine }
        return Palette.canvasDoorLine
    }

    private struct DoorSwing {
        let hingeX: Double
        let dirX: Double
        let leafLength: Double
        let placement: Placement
    }

    private static func drawSwingArcs(
        for door: LayoutObject,
        colors: DoorColors,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let width = door.placement.sizeM.x
        let halfW = width / 2.0
        let isDouble = width >= doubleDoorThresholdM
        let leafLength = min(isDouble ? halfW : width, maxLeafLengthM)
        guard leafLength > 0.1 else { return }

        let sides: [(hingeX: Double, dirX: Double)] = isDouble
            ? [(-halfW, 1.0), (halfW, -1.0)]
            : [(-halfW, 1.0)]

        for side in sides {
            let swing = DoorSwing(
                hingeX: side.hingeX,
                dirX: side.dirX,
                leafLength: leafLength,
                placement: door.placement
            )
            drawSingleSwing(swing, colors: colors, in: &context, transform: transform)
        }
    }

    private static func drawSingleSwing(
        _ swing: DoorSwing,
        colors: DoorColors,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let hingeLocal = SIMD2<Double>(swing.hingeX, 0)
        let openTipLocal = SIMD2<Double>(swing.hingeX, swing.leafLength)
        let hingeView = transform.toView(LayoutGeometry.toWorld(local: hingeLocal, in: swing.placement))
        let openTipView = transform.toView(LayoutGeometry.toWorld(local: openTipLocal, in: swing.placement))

        var sector = Path()
        sector.move(to: CGPoint(x: hingeView.x, y: hingeView.y))
        var arc = Path()
        for step in 0...arcSegmentCount {
            let angle = Double(step) / Double(arcSegmentCount) * (.pi / 2.0)
            let local = SIMD2<Double>(
                swing.hingeX + swing.dirX * swing.leafLength * cos(angle),
                swing.leafLength * sin(angle)
            )
            let view = transform.toView(LayoutGeometry.toWorld(local: local, in: swing.placement))
            let cgPoint = CGPoint(x: view.x, y: view.y)
            sector.addLine(to: cgPoint)
            if step == 0 {
                arc.move(to: cgPoint)
            } else {
                arc.addLine(to: cgPoint)
            }
        }
        sector.closeSubpath()

        context.fill(sector, with: .color(colors.fill.opacity(0.28)))
        context.stroke(
            arc,
            with: .color(colors.stroke.opacity(0.7)),
            style: StrokeStyle(lineWidth: 1.1, dash: [4, 3])
        )

        var leaf = Path()
        leaf.move(to: CGPoint(x: hingeView.x, y: hingeView.y))
        leaf.addLine(to: CGPoint(x: openTipView.x, y: openTipView.y))
        context.stroke(
            leaf,
            with: .color(colors.stroke),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )
    }

    private static func drawDisabledCross(
        corners: [SIMD2<Double>],
        color: Color,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard corners.count == 4 else { return }
        let points = corners.map {
            let viewPoint = transform.toView($0)
            return CGPoint(x: viewPoint.x, y: viewPoint.y)
        }
        var cross = Path()
        cross.move(to: points[0])
        cross.addLine(to: points[2])
        cross.move(to: points[1])
        cross.addLine(to: points[3])
        context.stroke(cross, with: .color(color), lineWidth: 1.2)
    }

    private static func drawLabel(
        for door: LayoutObject,
        isSelected: Bool,
        strokeColor: Color,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let trimmed = door.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Door" : trimmed
        let centerView = transform.toView(door.placement.center)
        let centerPoint = CGPoint(x: centerView.x, y: centerView.y)
        let labelColor = isSelected ? Color.white : strokeColor
        let text = Text(title)
            .font(Typography.canvasLabel(scaledBy: transform.scale))
            .foregroundStyle(labelColor)
        let resolved = context.resolve(text)
        let textSize = resolved.measure(in: CGSize(width: 200, height: 40))
        let pillRect = CGRect(
            x: centerPoint.x - textSize.width / 2 - 4,
            y: centerPoint.y - textSize.height / 2 - 1,
            width: textSize.width + 8,
            height: textSize.height + 2
        )
        let pill = Path(roundedRect: pillRect, cornerRadius: 3)
        context.fill(pill, with: .color(isSelected ? Palette.canvasSelection : Palette.canvasFloor.opacity(0.92)))
        context.stroke(pill, with: .color(strokeColor.opacity(0.5)), lineWidth: 0.75)
        context.draw(resolved, at: centerPoint, anchor: .center)
    }

    static func drawDirectionArrows(
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

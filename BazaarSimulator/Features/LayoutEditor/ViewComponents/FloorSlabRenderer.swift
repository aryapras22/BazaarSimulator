import SwiftUI
import simd

enum FloorSlabRenderer {
    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: state.object.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        context.fill(path, with: .color(Palette.canvasFloor))
        drawGrid(clippedTo: path, placement: state.object.placement, in: &context, transform: transform)

        let outline: Color
        let lineWidth: CGFloat
        if state.hasWarning {
            outline = Palette.canvasIssue
            lineWidth = 2.0
        } else if state.isSelected {
            outline = Palette.highlight
            lineWidth = 2.0
        } else if state.isHovered {
            outline = Palette.accentIcon
            lineWidth = 2.0
        } else {
            outline = Palette.canvasLine.opacity(0.4)
            lineWidth = 1.0
        }
        context.stroke(path, with: .color(outline), lineWidth: lineWidth)
        drawLabel(for: state.object, in: &context, transform: transform)
    }

    private static func drawGrid(
        clippedTo path: Path,
        placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let bounds = LayoutGeometry.bounds(of: placement)
        var clipped = context
        clipped.clip(to: path)
        let rulerScale = RulerScale(pointsPerMetre: transform.scale)
        let minor = rulerScale.gridMinorM
        let major = rulerScale.gridMajorM

        var minorPath = Path()
        var majorPath = Path()
        let startX = Int(floor(bounds.minX / minor))
        let endX = Int(ceil(bounds.maxX / minor))
        for index in startX...endX {
            let worldX = Double(index) * minor
            let viewX = transform.toView(SIMD2<Double>(worldX, 0)).x
            let isMajor = abs(remainder(worldX, major)) < 1e-6
            let topPt = CGPoint(x: viewX, y: transform.toView(SIMD2<Double>(0, bounds.minY)).y)
            let bottomPt = CGPoint(x: viewX, y: transform.toView(SIMD2<Double>(0, bounds.maxY)).y)
            if isMajor {
                majorPath.move(to: topPt)
                majorPath.addLine(to: bottomPt)
            } else {
                minorPath.move(to: topPt)
                minorPath.addLine(to: bottomPt)
            }
        }

        let startY = Int(floor(bounds.minY / minor))
        let endY = Int(ceil(bounds.maxY / minor))
        for index in startY...endY {
            let worldY = Double(index) * minor
            let viewY = transform.toView(SIMD2<Double>(0, worldY)).y
            let isMajor = abs(remainder(worldY, major)) < 1e-6
            let leftPt = CGPoint(x: transform.toView(SIMD2<Double>(bounds.minX, 0)).x, y: viewY)
            let rightPt = CGPoint(x: transform.toView(SIMD2<Double>(bounds.maxX, 0)).x, y: viewY)
            if isMajor {
                majorPath.move(to: leftPt)
                majorPath.addLine(to: rightPt)
            } else {
                minorPath.move(to: leftPt)
                minorPath.addLine(to: rightPt)
            }
        }

        clipped.stroke(minorPath, with: .color(Palette.canvasGridOnFloor), lineWidth: 0.5)
        clipped.stroke(majorPath, with: .color(Palette.canvasGridOnFloorMajor), lineWidth: 1.0)
    }

    private static func drawLabel(
        for object: LayoutObject,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= 10.0 else { return }
        let size = object.placement.sizeM
        guard min(size.x, size.y) >= 3.0 else { return }
        let trimmed = object.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Floor" else { return }

        let centerView = transform.toView(object.placement.center)
        let text = Text(trimmed)
            .font(Typography.canvasLabel(scaledBy: transform.scale))
            .foregroundStyle(Palette.canvasLine.opacity(0.8))
        context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
    }
}

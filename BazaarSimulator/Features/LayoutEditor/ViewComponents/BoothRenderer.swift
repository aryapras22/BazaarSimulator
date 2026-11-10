import SwiftUI
import simd

struct BoothDrawState: Sendable {
    let booth: LayoutObject
    let displayLabel: String
    let isSelected: Bool
    let isHovered: Bool
    let isGroupMember: Bool
    let isHoveredGroupMember: Bool
    let hasObjectWarning: Bool
    let blockedSides: OpenSides
    let categoryColor: LegendColor?
    var attractiveness: AttractivenessDisplay = .hidden
}

enum BoothRenderer {
    private static let stripThicknessM = 0.22

    static func draw(
        _ state: BoothDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: state.booth.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let fillColor: Color
        let strokeColor: Color
        if state.isSelected {
            fillColor = Palette.canvasSelection
            strokeColor = Palette.canvasLine
        } else {
            fillColor = state.attractiveness == .heat
                ? AttractivenessScale.color(for: state.booth.attractiveness)
                : Palette.canvasBoothFill
            strokeColor = Palette.canvasLine
        }

        context.fill(path, with: .color(fillColor))

        drawOpenSideStrips(for: state, in: &context, transform: transform)

        let outlineColor = state.hasObjectWarning ? Palette.canvasIssue : strokeColor
        let lineWidth: CGFloat = state.hasObjectWarning ? 2.0 : 1.0
        context.stroke(path, with: .color(outlineColor), lineWidth: lineWidth)

        if state.isHovered && !state.isSelected {
            context.stroke(path, with: .color(Palette.accentIcon), lineWidth: 2.0)
        }

        if state.isGroupMember || state.isHoveredGroupMember {
            let opacity = state.isGroupMember ? 1.0 : 0.5
            context.stroke(path, with: .color(Palette.highlight.opacity(opacity)), lineWidth: 2.0)
        }

        if state.isHovered, let categoryColor = state.categoryColor {
            drawCategoryDot(color: categoryColor, placement: state.booth.placement, in: &context, transform: transform)
        }

        drawAttractivenessMark(for: state, in: &context, transform: transform)

        if transform.scale >= 10.0 {
            let centerView = transform.toView(state.booth.placement.center)
            let labelColor = state.isSelected ? Color.white : strokeColor
            let text = Text(state.displayLabel)
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(labelColor)
            context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
        }
    }

    private static func drawAttractivenessMark(
        for state: BoothDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard state.attractiveness != .hidden, transform.scale >= 5.0 else { return }
        let placement = state.booth.placement
        let value = state.booth.attractiveness
        if state.attractiveness == .heat {
            guard transform.scale >= 16.0 else { return }
            let cornerLocal = SIMD2<Double>(placement.sizeM.x / 2.0, placement.sizeM.y / 2.0)
            let corner = transform.toView(LayoutGeometry.toWorld(local: cornerLocal, in: placement))
            let text = Text(DimensionInput.text(for: value))
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(state.isSelected ? Color.white : Palette.canvasLine)
            context.draw(text, at: CGPoint(x: corner.x - 3, y: corner.y - 2), anchor: .bottomTrailing)
            return
        }
        guard abs(value - AttractivenessScale.defaultValue) > 0.001 else { return }
        let cornerLocal = SIMD2<Double>(-placement.sizeM.x / 2.0, -placement.sizeM.y / 2.0)
        let corner = transform.toView(LayoutGeometry.toWorld(local: cornerLocal, in: placement))
        let radius: CGFloat = 3.5
        let rect = CGRect(x: corner.x + 2, y: corner.y + 2, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(AttractivenessScale.color(for: value)))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.canvasLine), lineWidth: 0.75)
    }

    private static func drawOpenSideStrips(
        for state: BoothDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let placement = state.booth.placement
        let halfW = placement.sizeM.x / 2.0
        let halfH = placement.sizeM.y / 2.0
        let depth = min(stripThicknessM, min(placement.sizeM.x, placement.sizeM.y) * 0.25)
        let halfDepth = depth / 2.0

        for side in OpenSides.ordered where state.booth.openSides.contains(side) {
            let localCenter: SIMD2<Double>
            let stripSize: SIMD2<Double>
            if side == .top {
                localCenter = SIMD2<Double>(0, -halfH + halfDepth)
                stripSize = SIMD2<Double>(placement.sizeM.x, depth)
            } else if side == .bottom {
                localCenter = SIMD2<Double>(0, halfH - halfDepth)
                stripSize = SIMD2<Double>(placement.sizeM.x, depth)
            } else if side == .left {
                localCenter = SIMD2<Double>(-halfW + halfDepth, 0)
                stripSize = SIMD2<Double>(depth, placement.sizeM.y)
            } else {
                localCenter = SIMD2<Double>(halfW - halfDepth, 0)
                stripSize = SIMD2<Double>(depth, placement.sizeM.y)
            }
            let worldCenter = LayoutGeometry.toWorld(local: localCenter, in: placement)
            let stripPlacement = Placement(
                center: worldCenter,
                sizeM: stripSize,
                rotationRadians: placement.rotationRadians
            )
            let stripPath = FloorRenderer.polygonPath(
                for: LayoutGeometry.corners(of: stripPlacement),
                transform: transform
            )
            let isBlocked = state.blockedSides.contains(side)
            let stripColor = isBlocked ? Palette.canvasIssue : Palette.canvasOpenSide
            context.fill(stripPath, with: .color(stripColor))
        }
    }

    private static func drawCategoryDot(
        color: LegendColor,
        placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let topRightLocal = SIMD2<Double>(placement.sizeM.x / 2.0 - 0.25, -placement.sizeM.y / 2.0 + 0.25)
        let dotWorld = LayoutGeometry.toWorld(local: topRightLocal, in: placement)
        let dotView = transform.toView(dotWorld)
        let radius: CGFloat = 4.0
        let rect = CGRect(x: dotView.x - radius, y: dotView.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color.swiftUIColor))
    }
}

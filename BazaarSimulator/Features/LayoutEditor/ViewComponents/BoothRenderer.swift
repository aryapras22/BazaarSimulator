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
    private static let stripThicknessM = 0.10

    static func draw(
        _ state: BoothDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: state.booth.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let isDisabled = DisabledObjectIndicator.isDisabled(state.booth)
        let usesHeatFill = !isDisabled && state.attractiveness == .heat
        let strokeColor = Palette.canvasLine

        context.fill(path, with: .color(fillColor(for: state, isDisabled: isDisabled, usesHeatFill: usesHeatFill)))

        if isDisabled {
            DisabledObjectIndicator.drawOverlay(
                for: state.booth.placement, isSelected: state.isSelected, in: &context, transform: transform
            )
        }

        drawOpenSideStrips(of: state.booth, blockedSides: state.blockedSides, in: &context, transform: transform)

        let outline = outlineStyle(for: state, usesHeatFill: usesHeatFill, defaultColor: strokeColor)
        context.stroke(path, with: .color(outline.color), lineWidth: outline.lineWidth)

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
            let isDarkFill = usesHeatFill
                ? AttractivenessScale.isDarkStep(for: state.booth.attractiveness)
                : state.isSelected
            let labelColor = isDarkFill ? Palette.canvasLabelOnDark : strokeColor
            let text = Text(state.displayLabel)
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(labelColor)
            context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
        }
    }

    private static func fillColor(for state: BoothDrawState, isDisabled: Bool, usesHeatFill: Bool) -> Color {
        if usesHeatFill {
            return AttractivenessScale.color(for: state.booth.attractiveness)
        }
        if state.isSelected {
            return Palette.canvasSelection
        }
        return isDisabled ? DisabledObjectIndicator.mutedFill : Palette.canvasBoothFill
    }

    private static func outlineStyle(
        for state: BoothDrawState,
        usesHeatFill: Bool,
        defaultColor: Color
    ) -> (color: Color, lineWidth: CGFloat) {
        if state.hasObjectWarning {
            return (Palette.canvasIssue, 2.0)
        }
        if state.isSelected && usesHeatFill {
            return (Palette.canvasSelection, 2.5)
        }
        return (defaultColor, 1.0)
    }

    private static func drawAttractivenessMark(
        for state: BoothDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard state.attractiveness == .dot, transform.scale >= 5.0 else { return }
        let placement = state.booth.placement
        let value = state.booth.attractiveness
        guard abs(value - AttractivenessScale.defaultValue) > 0.001 else { return }
        let cornerLocal = SIMD2<Double>(-placement.sizeM.x / 2.0, -placement.sizeM.y / 2.0)
        let corner = transform.toView(LayoutGeometry.toWorld(local: cornerLocal, in: placement))
        let radius: CGFloat = 3.5
        let rect = CGRect(x: corner.x + 2, y: corner.y + 2, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(AttractivenessScale.color(for: value)))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.canvasLine), lineWidth: 0.75)
    }

    /// Booths and entertainment mark closed sides in dark blue and draw no strip on open sides.
    static func drawOpenSideStrips(
        of object: LayoutObject,
        blockedSides: OpenSides,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let placement = object.placement
        let halfW = placement.sizeM.x / 2.0
        let halfH = placement.sizeM.y / 2.0
        let depth = min(stripThicknessM, min(placement.sizeM.x, placement.sizeM.y) * 0.25)
        let halfDepth = depth / 2.0

        for side in OpenSides.ordered where !object.openSides.contains(side) {
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
            context.fill(stripPath, with: .color(Palette.canvasLine))
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

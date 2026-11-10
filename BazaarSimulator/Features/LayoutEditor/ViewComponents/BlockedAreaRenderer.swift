import SwiftUI
import simd

enum BlockedAreaRenderer {
    static let hatchSpacingM = 0.8
    private static let minimumLabelScale = 8.0
    private static let minimumDimensionForLabelM = 3.0

    static func draw(
        _ state: ObjectDrawState,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let corners = LayoutGeometry.corners(of: state.object.placement)
        let path = FloorRenderer.polygonPath(for: corners, transform: transform)

        let isSelected = state.isSelected
        let isHovered = state.isHovered

        context.fill(path, with: .color(Palette.canvasLineGlow.opacity(isSelected ? 0.35 : 0.20)))
        drawHatch(clippedTo: path, placement: state.object.placement, in: &context, transform: transform)

        let outline: Color
        let lineWidth: CGFloat
        if state.hasWarning {
            outline = Palette.canvasIssue
            lineWidth = 2
        } else if isSelected {
            outline = Palette.highlight
            lineWidth = 2
        } else if isHovered {
            outline = Palette.accentIcon
            lineWidth = 2
        } else {
            outline = Palette.canvasLine.opacity(0.6)
            lineWidth = 1
        }
        context.stroke(path, with: .color(outline), lineWidth: lineWidth)

        drawLabel(for: state.object, in: &context, transform: transform)
    }

    static func drawHatch(
        clippedTo path: Path,
        placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let bounds = LayoutGeometry.bounds(of: placement)
        var clipped = context
        clipped.clip(to: path)
        var hatch = Path()
        let firstIndex = Int(floor((bounds.minX - bounds.maxY) / hatchSpacingM))
        let lastIndex = Int(ceil((bounds.maxX - bounds.minY) / hatchSpacingM))
        for index in firstIndex...lastIndex {
            let offset = Double(index) * hatchSpacingM
            let start = transform.toView(SIMD2<Double>(bounds.minX, bounds.minX - offset))
            let end = transform.toView(SIMD2<Double>(bounds.maxX, bounds.maxX - offset))
            hatch.move(to: CGPoint(x: start.x, y: start.y))
            hatch.addLine(to: CGPoint(x: end.x, y: end.y))
        }
        clipped.stroke(hatch, with: .color(Palette.canvasHatch), lineWidth: 1)
    }

    private static func drawLabel(
        for object: LayoutObject,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= minimumLabelScale else { return }
        let size = object.placement.sizeM
        guard min(size.x, size.y) >= minimumDimensionForLabelM else { return }
        let trimmed = object.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Restricted area", trimmed != "Blocked area" else { return }

        let centerView = transform.toView(object.placement.center)
        let text = Text(trimmed)
            .font(Typography.canvasLabel(scaledBy: transform.scale))
            .foregroundStyle(Palette.canvasLine.opacity(0.8))
        context.draw(text, at: CGPoint(x: centerView.x, y: centerView.y), anchor: .center)
    }
}

#Preview("Blocked Area Renderer") {
    Canvas { context, _ in
        let transform = CanvasTransform(scale: 10, offset: SIMD2<Double>(20, 20))
        let area = LayoutObject(
            kind: .closedArea,
            label: "Storage",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(8, 6))
        )
        let state = ObjectDrawState(
            object: area,
            isSelected: true,
            isHovered: false,
            hasWarning: false
        )
        BlockedAreaRenderer.draw(state, in: &context, transform: transform)
    }
    .frame(width: 300, height: 250)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

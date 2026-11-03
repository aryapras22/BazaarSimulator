import SwiftUI
import simd

struct CanvasRulers: View {
    static let topHeight: CGFloat = 24
    static let leftWidth: CGFloat = 36

    let transform: CanvasTransform
    let pointer: CanvasPointer
    let selectionBounds: BoundingBox?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                corner
                RulerBand(
                    axis: .horizontal,
                    transform: transform,
                    pointer: pointer,
                    selection: selectionBounds.map { $0.minX...$0.maxX }
                )
                .frame(height: Self.topHeight)
            }
            HStack(spacing: 0) {
                RulerBand(
                    axis: .vertical,
                    transform: transform,
                    pointer: pointer,
                    selection: selectionBounds.map { $0.minY...$0.maxY }
                )
                .frame(width: Self.leftWidth)
                Color.clear.allowsHitTesting(false)
            }
        }
    }

    private var corner: some View {
        Text("m")
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
            .frame(width: Self.leftWidth, height: Self.topHeight)
            .background(Palette.surface)
            .contentShape(Rectangle())
    }
}

private enum RulerAxis {
    case horizontal
    case vertical
}

private struct RulerBand: View {
    private static let labelledTickLength: CGFloat = 8
    private static let minorTickLength: CGFloat = 4

    let axis: RulerAxis
    let transform: CanvasTransform
    let pointer: CanvasPointer
    let selection: ClosedRange<Double>?

    var body: some View {
        let markerValue = pointer.world.map { axis == .horizontal ? $0.x : $0.y }
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Palette.surface))
            drawSelection(in: &context, size: size)
            drawTicks(in: &context, size: size)
            drawMarker(markerValue, in: &context, size: size)
            drawEdge(in: &context, size: size)
        }
        .contentShape(Rectangle())
    }

    private func position(of value: Double) -> CGFloat {
        switch axis {
        case .horizontal: return CGFloat(transform.toView(SIMD2<Double>(value, 0)).x)
        case .vertical: return CGFloat(transform.toView(SIMD2<Double>(0, value)).y)
        }
    }

    private func line(from start: CGFloat, to end: CGFloat, at offset: CGFloat) -> Path {
        var path = Path()
        switch axis {
        case .horizontal:
            path.move(to: CGPoint(x: offset, y: start))
            path.addLine(to: CGPoint(x: offset, y: end))
        case .vertical:
            path.move(to: CGPoint(x: start, y: offset))
            path.addLine(to: CGPoint(x: end, y: offset))
        }
        return path
    }

    private func drawSelection(in context: inout GraphicsContext, size: CGSize) {
        guard let selection else { return }
        let start = position(of: selection.lowerBound)
        let end = position(of: selection.upperBound)
        let rect = axis == .horizontal
            ? CGRect(x: start, y: 0, width: end - start, height: size.height)
            : CGRect(x: 0, y: start, width: size.width, height: end - start)
        context.fill(Path(rect), with: .color(Palette.accent.opacity(0.2)))
    }

    private func drawTicks(in context: inout GraphicsContext, size: CGSize) {
        let scale = RulerScale(pointsPerMetre: transform.scale)
        let step = scale.tickStepM ?? scale.labelStepM
        let extent = axis == .horizontal ? size.width : size.height
        let thickness = axis == .horizontal ? size.height : size.width
        let visibleStart = axis == .horizontal ? transform.toWorld(.zero).x : transform.toWorld(.zero).y
        let visibleEnd = visibleStart + Double(extent) / transform.scale

        var ticks = Path()
        for index in Int(ceil(visibleStart / step))...Int(floor(visibleEnd / step)) {
            let value = Double(index) * step
            let offset = position(of: value)
            let isLabelled = abs(remainder(value, scale.labelStepM)) < 1e-6
            let length = isLabelled ? Self.labelledTickLength : Self.minorTickLength
            ticks.addPath(line(from: thickness - length, to: thickness, at: offset))
            if isLabelled { drawLabel(value, at: offset, in: &context) }
        }
        context.stroke(ticks, with: .color(Palette.textTertiary), lineWidth: 1)
    }

    private func drawLabel(_ value: Double, at offset: CGFloat, in context: inout GraphicsContext) {
        let text = Text("\(DimensionInput.text(for: value)) m")
            .font(Typography.caption)
            .foregroundStyle(Palette.textSecondary)
        switch axis {
        case .horizontal:
            context.draw(text, at: CGPoint(x: offset + 3, y: 3), anchor: .topLeading)
        case .vertical:
            context.draw(text, at: CGPoint(x: 3, y: offset - 2), anchor: .bottomLeading)
        }
    }

    private func drawMarker(_ value: Double?, in context: inout GraphicsContext, size: CGSize) {
        guard let value else { return }
        let thickness = axis == .horizontal ? size.height : size.width
        let marker = line(from: 0, to: thickness, at: position(of: value))
        context.stroke(marker, with: .color(Palette.rulerMarker), lineWidth: 1)
    }

    private func drawEdge(in context: inout GraphicsContext, size: CGSize) {
        let thickness = axis == .horizontal ? size.height : size.width
        let extent = axis == .horizontal ? size.width : size.height
        var edge = Path()
        switch axis {
        case .horizontal:
            edge.move(to: CGPoint(x: 0, y: thickness))
            edge.addLine(to: CGPoint(x: extent, y: thickness))
        case .vertical:
            edge.move(to: CGPoint(x: thickness, y: 0))
            edge.addLine(to: CGPoint(x: thickness, y: extent))
        }
        context.stroke(edge, with: .color(Palette.surfaceBorder), lineWidth: 1)
    }
}

#Preview("Rulers at three scales") {
    let pointer = CanvasPointer()
    pointer.world = SIMD2<Double>(31.4, 22.3)
    return VStack(spacing: Spacing.l) {
        ForEach([4.0, 10.0, 40.0], id: \.self) { scale in
            CanvasRulers(
                transform: CanvasTransform(scale: scale, offset: SIMD2<Double>(60, 40)),
                pointer: pointer,
                selectionBounds: BoundingBox(minX: 10, maxX: 12.5, minY: 5, maxY: 7.5)
            )
            .frame(width: 480, height: 200)
            .background(Palette.background)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}

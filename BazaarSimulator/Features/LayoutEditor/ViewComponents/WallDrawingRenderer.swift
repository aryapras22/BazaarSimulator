import SwiftUI
import simd

enum WallDrawingRenderer {
    static func draw(
        drawing: WallDrawing,
        currentPointer: SIMD2<Double>?,
        lockAngle: Bool,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let points = drawing.points
        if points.count >= 2 {
            drawCommittedChain(points: points, in: &context, transform: transform)
        }

        for point in points {
            drawJoint(at: point, in: &context, transform: transform)
        }

        guard let last = points.last, let current = currentPointer else { return }

        if lockAngle {
            drawAngleGuide(from: last, toward: current, in: &context, transform: transform)
        }

        drawLiveSegment(
            from: last,
            to: current,
            typedLength: drawing.typedLength,
            in: &context,
            transform: transform
        )
    }

    private static func drawCommittedChain(
        points: [SIMD2<Double>],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        var path = Path()
        guard let first = points.first else { return }
        let firstScreen = transform.toView(first)
        path.move(to: CGPoint(x: firstScreen.x, y: firstScreen.y))

        for point in points.dropFirst() {
            let screenPoint = transform.toView(point)
            path.addLine(to: CGPoint(x: screenPoint.x, y: screenPoint.y))
        }

        context.stroke(path, with: .color(Palette.canvasLine), lineWidth: 3.0)
    }

    private static func drawJoint(
        at point: SIMD2<Double>,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let screenPoint = transform.toView(point)
        let radius: CGFloat = 4.0
        let rect = CGRect(
            x: CGFloat(screenPoint.x) - radius,
            y: CGFloat(screenPoint.y) - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        context.fill(Path(ellipseIn: rect), with: .color(Palette.canvasLine))
    }

    private static func drawAngleGuide(
        from start: SIMD2<Double>,
        toward target: SIMD2<Double>,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let vector = target - start
        let length = simd_length(vector)
        guard length > 1e-6 else { return }
        let direction = vector / length
        let guideStart = start - direction * 50.0
        let guideEnd = start + direction * 50.0

        let startScreen = transform.toView(guideStart)
        let endScreen = transform.toView(guideEnd)
        var guidePath = Path()
        guidePath.move(to: CGPoint(x: startScreen.x, y: startScreen.y))
        guidePath.addLine(to: CGPoint(x: endScreen.x, y: endScreen.y))

        let strokeStyle = StrokeStyle(lineWidth: 1.0, dash: [4.0, 4.0])
        context.stroke(guidePath, with: .color(Palette.textSecondary.opacity(0.5)), style: strokeStyle)
    }

    private static func drawLiveSegment(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        typedLength: String,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let startScreen = transform.toView(start)
        let endScreen = transform.toView(end)
        var path = Path()
        path.move(to: CGPoint(x: startScreen.x, y: startScreen.y))
        path.addLine(to: CGPoint(x: endScreen.x, y: endScreen.y))

        context.stroke(path, with: .color(Palette.highlight), lineWidth: 2.0)

        let midpoint = (start + end) / 2.0
        let midScreen = transform.toView(midpoint)
        let chipLocation = CGPoint(x: CGFloat(midScreen.x) + 12.0, y: CGFloat(midScreen.y) + 12.0)

        let length = simd_distance(start, end)
        let lengthText = typedLength.isEmpty ? "\(DimensionInput.text(for: length)) m" : "\(typedLength) m"
        SelectionDimensionRenderer.drawSizeChip(lengthText, near: chipLocation, in: &context)
    }
}

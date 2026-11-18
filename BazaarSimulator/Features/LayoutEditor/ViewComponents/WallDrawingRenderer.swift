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
        if points.isEmpty, let current = currentPointer {
            drawHoverDot(at: current, in: &context, transform: transform)
            if !drawing.typedLength.isEmpty {
                let screenPoint = transform.toView(current)
                let chipLocation = CGPoint(x: CGFloat(screenPoint.x) + 12.0, y: CGFloat(screenPoint.y) + 12.0)
                SelectionDimensionRenderer.drawSizeChip("\(drawing.typedLength) m", near: chipLocation, in: &context)
            }
            return
        }

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
            label: liveLabel(for: drawing, from: last, to: current),
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

        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let length = simd_distance(start, end)
            guard length > 0.01 else { continue }
            let midpoint = (start + end) / 2.0
            let midScreen = transform.toView(midpoint)
            let chipLocation = CGPoint(x: CGFloat(midScreen.x) + 12.0, y: CGFloat(midScreen.y) + 12.0)
            let lengthText = "\(DimensionInput.text(for: length)) m"
            SelectionDimensionRenderer.drawSizeChip(lengthText, near: chipLocation, in: &context)
        }
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

    private static func drawHoverDot(
        at point: SIMD2<Double>,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let screenPoint = transform.toView(point)
        let radius: CGFloat = 5.0
        let rect = CGRect(
            x: CGFloat(screenPoint.x) - radius,
            y: CGFloat(screenPoint.y) - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        context.fill(Path(ellipseIn: rect), with: .color(Palette.highlight))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.surface), lineWidth: 1.5)
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
        label: String,
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

        SelectionDimensionRenderer.drawSizeChip(label, near: chipLocation, in: &context)
    }

    private static func liveLabel(
        for drawing: WallDrawing,
        from start: SIMD2<Double>,
        to end: SIMD2<Double>
    ) -> String {
        let measured = DimensionInput.text(for: simd_distance(start, end))
        let length = drawing.typedLength.isEmpty ? measured : drawing.typedLength
        let previous = drawing.points.count >= 2 ? drawing.points[drawing.points.count - 2] : drawing.previousPoint
        let angle = angleDegrees(from: start, to: end, previous: previous).map { " · \($0)°" } ?? ""
        return "\(length) m\(angle)"
    }

    /// The angle between the new segment and the one before it, or its direction from the x axis for the first.
    static func angleDegrees(from start: SIMD2<Double>, to end: SIMD2<Double>, previous: SIMD2<Double>?) -> Int? {
        let direction = end - start
        guard simd_length(direction) > 1e-6 else { return nil }
        guard let previous else {
            let degrees = atan2(direction.y, direction.x) * 180 / .pi
            return Int((degrees + 360).truncatingRemainder(dividingBy: 360).rounded()) % 360
        }
        let back = previous - start
        guard simd_length(back) > 1e-6 else { return nil }
        let cosine = simd_dot(direction, back) / (simd_length(direction) * simd_length(back))
        return Int((acos(min(max(cosine, -1), 1)) * 180 / .pi).rounded())
    }
}

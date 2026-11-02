import SwiftUI
import simd

enum FloorRenderer {
    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        transform: CanvasTransform,
        layout: Layout
    ) {
        drawGrid(in: &context, size: size, transform: transform, layoutSize: layout.sizeM)
        drawPolygon(layout.hall, in: &context, transform: transform)
        drawPolygon(layout.lobby, in: &context, transform: transform)
        drawClosedAreas(in: &context, transform: transform, objects: layout.objects)
        drawZones(layout.zones, in: &context, transform: transform)
    }

    static func polygonPath(for points: [SIMD2<Double>], transform: CanvasTransform) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        let start = transform.toView(first)
        path.move(to: CGPoint(x: start.x, y: start.y))
        for point in points.dropFirst() {
            let viewPoint = transform.toView(point)
            path.addLine(to: CGPoint(x: viewPoint.x, y: viewPoint.y))
        }
        path.closeSubpath()
        return path
    }

    private static func drawGrid(
        in context: inout GraphicsContext,
        size: CGSize,
        transform: CanvasTransform,
        layoutSize: SIMD2<Double>
    ) {
        let topLeftWorld = transform.toWorld(.zero)
        let bottomRightWorld = transform.toWorld(SIMD2<Double>(Double(size.width), Double(size.height)))
        let startX = Int(floor(min(0, topLeftWorld.x) / 5.0)) * 5
        let endX = Int(ceil(max(layoutSize.x, bottomRightWorld.x) / 5.0)) * 5
        let startY = Int(floor(min(0, topLeftWorld.y) / 5.0)) * 5
        let endY = Int(ceil(max(layoutSize.y, bottomRightWorld.y) / 5.0)) * 5

        let showMinor = transform.scale >= 12.0
        var minorPath = Path()
        var majorPath = Path()

        let step = showMinor ? 1 : 5
        for worldX in stride(from: startX, through: endX, by: step) {
            let viewX = transform.toView(SIMD2<Double>(Double(worldX), 0)).x
            if worldX % 5 == 0 {
                majorPath.move(to: CGPoint(x: viewX, y: 0))
                majorPath.addLine(to: CGPoint(x: viewX, y: size.height))
            } else {
                minorPath.move(to: CGPoint(x: viewX, y: 0))
                minorPath.addLine(to: CGPoint(x: viewX, y: size.height))
            }
        }

        for worldY in stride(from: startY, through: endY, by: step) {
            let viewY = transform.toView(SIMD2<Double>(0, Double(worldY))).y
            if worldY % 5 == 0 {
                majorPath.move(to: CGPoint(x: 0, y: viewY))
                majorPath.addLine(to: CGPoint(x: size.width, y: viewY))
            } else {
                minorPath.move(to: CGPoint(x: 0, y: viewY))
                minorPath.addLine(to: CGPoint(x: size.width, y: viewY))
            }
        }

        if showMinor {
            context.stroke(minorPath, with: .color(Palette.canvasGridLine.opacity(0.6)), lineWidth: 0.5)
        }
        context.stroke(majorPath, with: .color(Palette.canvasGridLine), lineWidth: 1.0)
    }

    private static func drawPolygon(
        _ points: [SIMD2<Double>],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard points.count >= 3 else { return }
        let path = polygonPath(for: points, transform: transform)
        context.fill(path, with: .color(Palette.canvasFloor))
        context.stroke(path, with: .color(Palette.canvasLineGlow), lineWidth: 4.0)
        context.stroke(path, with: .color(Palette.canvasLine), lineWidth: 1.5)
    }

    private static func drawClosedAreas(
        in context: inout GraphicsContext,
        transform: CanvasTransform,
        objects: [LayoutObject]
    ) {
        for object in objects where object.kind == .closedArea {
            let corners = LayoutGeometry.corners(of: object.placement)
            let path = polygonPath(for: corners, transform: transform)
            context.fill(path, with: .color(Palette.canvasFlowFill.opacity(0.45)))
            context.stroke(
                path,
                with: .color(Palette.canvasLine.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
        }
    }

    private static func drawZones(
        _ zones: [LayoutZone],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= 10.0 else { return }
        for zone in zones {
            let pos = transform.toView(zone.labelPosition)
            let text = Text(zone.label)
                .font(Typography.canvasLabel(scaledBy: transform.scale))
                .foregroundStyle(Palette.canvasLine.opacity(0.75))
            context.draw(text, at: CGPoint(x: pos.x, y: pos.y), anchor: .center)
        }
    }
}

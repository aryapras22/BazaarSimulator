import SwiftUI
import simd

enum FloorRenderer {
    private struct GridColors {
        let minor: Color
        let major: Color
    }

    private static let hatchSpacingM = 0.8
    private static let hatchFillOpacity = 0.25

    static func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        transform: CanvasTransform,
        layout: Layout
    ) {
        let rulerScale = RulerScale(pointsPerMetre: transform.scale)
        drawGrid(
            in: &context, size: size, transform: transform, scale: rulerScale,
            colors: GridColors(minor: Palette.canvasGridLine.opacity(0.6), major: Palette.canvasGridLine)
        )
        drawPolygon(layout.hall, in: &context, transform: transform)
        drawPolygon(layout.lobby, in: &context, transform: transform)
        drawGridOnFloor(in: &context, size: size, transform: transform, scale: rulerScale, layout: layout)
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
        scale: RulerScale,
        colors: GridColors
    ) {
        let topLeftWorld = transform.toWorld(.zero)
        let bottomRightWorld = transform.toWorld(SIMD2<Double>(Double(size.width), Double(size.height)))
        let minor = scale.gridMinorM
        var minorPath = Path()
        var majorPath = Path()

        func isMajor(_ value: Double) -> Bool {
            abs(remainder(value, scale.gridMajorM)) < 1e-6
        }

        for index in Int(floor(topLeftWorld.x / minor))...Int(ceil(bottomRightWorld.x / minor)) {
            let worldX = Double(index) * minor
            let viewX = transform.toView(SIMD2<Double>(worldX, 0)).x
            if isMajor(worldX) {
                majorPath.move(to: CGPoint(x: viewX, y: 0))
                majorPath.addLine(to: CGPoint(x: viewX, y: size.height))
            } else {
                minorPath.move(to: CGPoint(x: viewX, y: 0))
                minorPath.addLine(to: CGPoint(x: viewX, y: size.height))
            }
        }

        for index in Int(floor(topLeftWorld.y / minor))...Int(ceil(bottomRightWorld.y / minor)) {
            let worldY = Double(index) * minor
            let viewY = transform.toView(SIMD2<Double>(0, worldY)).y
            if isMajor(worldY) {
                majorPath.move(to: CGPoint(x: 0, y: viewY))
                majorPath.addLine(to: CGPoint(x: size.width, y: viewY))
            } else {
                minorPath.move(to: CGPoint(x: 0, y: viewY))
                minorPath.addLine(to: CGPoint(x: size.width, y: viewY))
            }
        }

        context.stroke(minorPath, with: .color(colors.minor), lineWidth: 0.5)
        context.stroke(majorPath, with: .color(colors.major), lineWidth: 1.0)
    }

    private static func drawGridOnFloor(
        in context: inout GraphicsContext,
        size: CGSize,
        transform: CanvasTransform,
        scale: RulerScale,
        layout: Layout
    ) {
        var floorPath = polygonPath(for: layout.hall, transform: transform)
        floorPath.addPath(polygonPath(for: layout.lobby, transform: transform))
        var clipped = context
        clipped.clip(to: floorPath)
        drawGrid(
            in: &clipped, size: size, transform: transform, scale: scale,
            colors: GridColors(minor: Palette.canvasGridOnFloor, major: Palette.canvasGridOnFloorMajor)
        )
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
            context.fill(path, with: .color(Palette.canvasFlowFill.opacity(hatchFillOpacity)))
            var clipped = context
            clipped.clip(to: path)
            clipped.stroke(
                hatchPath(over: LayoutGeometry.bounds(of: object.placement), transform: transform),
                with: .color(Palette.canvasHatch),
                lineWidth: 1
            )
        }
    }

    private static func hatchPath(over bounds: BoundingBox, transform: CanvasTransform) -> Path {
        var path = Path()
        let firstIndex = Int(floor((bounds.minX - bounds.maxY) / hatchSpacingM))
        let lastIndex = Int(ceil((bounds.maxX - bounds.minY) / hatchSpacingM))
        for index in firstIndex...lastIndex {
            let offset = Double(index) * hatchSpacingM
            let start = transform.toView(SIMD2<Double>(bounds.minX, bounds.minX - offset))
            let end = transform.toView(SIMD2<Double>(bounds.maxX, bounds.maxX - offset))
            path.move(to: CGPoint(x: start.x, y: start.y))
            path.addLine(to: CGPoint(x: end.x, y: end.y))
        }
        return path
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

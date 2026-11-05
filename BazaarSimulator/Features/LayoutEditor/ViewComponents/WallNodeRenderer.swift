import SwiftUI
import simd

enum WallNodeRenderer {
    static func draw(
        snapshot: CanvasDisplaySnapshot,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        guard snapshot.activeLayer == .structure else { return }

        let graph = WallGraph(layout: snapshot.layout)
        guard !graph.nodes.isEmpty else { return }

        let reachM = 60.0 / max(transform.scale, 1.0)
        let hitM = 10.0 / max(transform.scale, 1.0)
        let hoverWorld = snapshot.hoverWorld

        let selectedWall = snapshot.selectionID.flatMap { selID in
            snapshot.layout.objects.first { $0.id == selID && $0.kind == .wall }
        }

        var visibleNodes: [WallGraph.Node] = []
        for node in graph.nodes {
            let isNearHover: Bool
            if let hoverWorld {
                isNearHover = simd_distance(node.position, hoverWorld) <= reachM
            } else {
                isNearHover = false
            }

            let isIncidentToSelected: Bool
            if let selID = selectedWall?.id {
                isIncidentToSelected = node.incidents.contains { $0.wallID == selID }
            } else {
                isIncidentToSelected = false
            }

            if isNearHover || isIncidentToSelected {
                visibleNodes.append(node)
            }
        }

        for node in visibleNodes {
            let isHovered = hoverWorld.map { simd_distance(node.position, $0) <= hitM } ?? false
            drawSolidDot(
                at: node.position,
                isHovered: isHovered,
                transform: transform,
                in: &context
            )
        }

        if let selectedWall {
            let isHovered = hoverWorld.map { simd_distance(selectedWall.placement.center, $0) <= hitM } ?? false
            drawHollowDot(
                at: selectedWall.placement.center,
                isHovered: isHovered,
                transform: transform,
                in: &context
            )
        }
    }

    private static func drawSolidDot(
        at point: SIMD2<Double>,
        isHovered: Bool,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let screenPoint = transform.toView(point)
        let radius: CGFloat = 4.0
        let rect = CGRect(
            x: CGFloat(screenPoint.x) - radius,
            y: CGFloat(screenPoint.y) - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        let fillColor = isHovered ? Palette.highlight : Palette.canvasLine
        context.fill(Path(ellipseIn: rect), with: .color(fillColor))
        context.stroke(Path(ellipseIn: rect), with: .color(Palette.surface), lineWidth: 1.5)
    }

    private static func drawHollowDot(
        at point: SIMD2<Double>,
        isHovered: Bool,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let screenPoint = transform.toView(point)
        let radius: CGFloat = 4.0
        let rect = CGRect(
            x: CGFloat(screenPoint.x) - radius,
            y: CGFloat(screenPoint.y) - radius,
            width: radius * 2.0,
            height: radius * 2.0
        )
        let strokeColor = isHovered ? Palette.highlight : Palette.canvasLine
        context.fill(Path(ellipseIn: rect), with: .color(Palette.surface))
        context.stroke(Path(ellipseIn: rect), with: .color(strokeColor), lineWidth: 1.5)
    }
}

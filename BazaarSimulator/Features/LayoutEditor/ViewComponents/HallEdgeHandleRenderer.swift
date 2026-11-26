import SwiftUI
import simd

enum HallEdgeHandleRenderer {
    static func draw(
        snapshot: CanvasDisplaySnapshot,
        drag: CanvasDragState,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        guard snapshot.activeLayer == .structure else { return }
        let hall = drag.previewHall ?? snapshot.layout.hall
        guard hall.count >= 3 else { return }
        drawSplitPoints(in: hall, hoverWorld: snapshot.hoverWorld, transform: transform, in: &context)
        drawMidpointHandles(snapshot: snapshot, drag: drag, transform: transform, in: &context)
    }

    private static func drawMidpointHandles(
        snapshot: CanvasDisplaySnapshot,
        drag: CanvasDragState,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let hall = drag.previewHall ?? snapshot.layout.hall
        let hoverWorld = snapshot.hoverWorld
        let isDragging = drag.previewHall != nil
        let reachM = 60.0 / max(transform.scale, 1.0)
        let hitM = 10.0 / max(transform.scale, 1.0)
        for edge in hall.indices {
            let midpoint = HallEdges.midpoint(of: edge, in: hall)
            let distance = hoverWorld.map { simd_distance(midpoint, $0) }
            guard isDragging || (distance ?? .infinity) <= reachM else { continue }
            let isHovered = (distance ?? .infinity) <= hitM
            let center = transform.toView(midpoint)
            let rect = CGRect(x: CGFloat(center.x) - 4, y: CGFloat(center.y) - 4, width: 8, height: 8)
            let path = Path(roundedRect: rect, cornerRadius: 1.5)
            context.fill(path, with: .color(Palette.surface))
            context.stroke(path, with: .color(isHovered ? Palette.highlight : Palette.canvasLine), lineWidth: 1.5)
        }
    }

    private static func drawSplitPoints(
        in hall: [SIMD2<Double>],
        hoverWorld: SIMD2<Double>?,
        transform: CanvasTransform,
        in context: inout GraphicsContext
    ) {
        let hitM = 10.0 / max(transform.scale, 1.0)
        for index in hall.indices where HallEdges.isSplitVertex(at: index, in: hall) {
            let vertex = hall[index]
            let isHovered = hoverWorld.map { simd_distance(vertex, $0) <= hitM } ?? false
            let center = transform.toView(vertex)
            let rect = CGRect(x: CGFloat(center.x) - 3.5, y: CGFloat(center.y) - 3.5, width: 7, height: 7)
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(Palette.surface))
            context.stroke(path, with: .color(isHovered ? Palette.highlight : Palette.canvasLine), lineWidth: 1.5)
        }
    }
}

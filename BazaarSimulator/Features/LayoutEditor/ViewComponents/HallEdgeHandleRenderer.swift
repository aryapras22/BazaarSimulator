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
        let hoverWorld = snapshot.hoverWorld
        let isDragging = drag.previewHall != nil
        guard hall.count >= 3 else { return }
        let reachM = 60.0 / max(transform.scale, 1.0)
        let hitM = 10.0 / max(transform.scale, 1.0)
        for edge in hall.indices {
            let midpoint = HallEdges.midpoint(of: edge, in: hall)
            let distance = hoverWorld.map { simd_distance(midpoint, $0) }
            guard isDragging || (distance ?? .infinity) <= reachM else { continue }
            let isHovered = (distance ?? .infinity) <= hitM
            let center = transform.toView(midpoint)
            let rect = CGRect(x: CGFloat(center.x) - 4, y: CGFloat(center.y) - 4, width: 8, height: 8)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Palette.surface))
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 1.5),
                with: .color(isHovered ? Palette.highlight : Palette.canvasLine),
                lineWidth: 1.5
            )
        }
    }
}

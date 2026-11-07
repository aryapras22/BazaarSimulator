import SwiftUI
import simd

/// Draws tables and chairs under the booths. They are read-only, so they carry no selection or hover state.
enum FurnitureRenderer {
    static func draw(
        _ furniture: [LayoutFurniture],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        for piece in furniture {
            let path = FloorRenderer.polygonPath(for: LayoutGeometry.corners(of: piece.placement), transform: transform)
            let isTable = piece.kind == .table
            context.fill(path, with: .color(Palette.canvasLine.opacity(isTable ? 0.14 : 0.08)))
            context.stroke(path, with: .color(Palette.canvasLine.opacity(isTable ? 0.55 : 0.4)), lineWidth: 0.8)
        }
    }
}

import SwiftUI
import simd

enum MarkerRenderer {
    static func draw(
        markers: [LayoutMarker],
        tab: EditorTab,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard tab == .flow else { return }
        for marker in markers {
            let pointView = transform.toView(marker.position)
            let radius: CGFloat = 5.0
            let circleRect = CGRect(
                x: pointView.x - radius,
                y: pointView.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let fill = marker.kind == .spawn ? Palette.highlight : Palette.canvasLine
            let circlePath = Path(ellipseIn: circleRect)
            context.fill(circlePath, with: .color(fill))
            context.stroke(circlePath, with: .color(Palette.canvasFloor), lineWidth: 1.5)

            if transform.scale >= 10.0 {
                let text = Text(marker.label)
                    .font(Typography.canvasLabel(scaledBy: transform.scale))
                    .foregroundStyle(Palette.canvasLine)
                context.draw(
                    text,
                    at: CGPoint(x: pointView.x, y: pointView.y - radius - 6),
                    anchor: .bottom
                )
            }
        }
    }
}

import SwiftUI
import simd

struct GroupClusterDisplay: Hashable, Sendable {
    let label: String
    let bounds: BoundingBox
    let categoryColor: LegendColor?
    let isSelected: Bool
    let isHovered: Bool
}

enum GroupOverlayRenderer {
    static let minimumScale = 6.0
    private static let outlineInsetM = 0.3
    private static let chipOffsetPt: CGFloat = 4
    private static let chipPaddingPt: CGFloat = 4
    private static let dotDiameterPt: CGFloat = 6

    static func draw(
        _ clusters: [GroupClusterDisplay],
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= minimumScale else { return }
        for cluster in clusters where cluster.isSelected || cluster.isHovered {
            drawOutline(of: cluster, in: &context, transform: transform)
        }
        for cluster in clusters {
            drawChip(for: cluster, in: &context, transform: transform)
        }
    }

    private static func drawOutline(
        of cluster: GroupClusterDisplay,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let topLeft = transform.toView(
            SIMD2<Double>(cluster.bounds.minX - outlineInsetM, cluster.bounds.minY - outlineInsetM)
        )
        let bottomRight = transform.toView(
            SIMD2<Double>(cluster.bounds.maxX + outlineInsetM, cluster.bounds.maxY + outlineInsetM)
        )
        let rect = CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
        let opacity = cluster.isSelected ? 1.0 : 0.5
        context.stroke(
            Path(rect),
            with: .color(Palette.highlight.opacity(opacity)),
            style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
        )
    }

    private static func drawChip(
        for cluster: GroupClusterDisplay,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let label = context.resolve(
            Text(cluster.label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
        )
        let textSize = label.measure(in: CGSize(width: 240, height: 40))
        let dotWidth = cluster.categoryColor == nil ? 0 : dotDiameterPt + chipPaddingPt
        let chipSize = CGSize(
            width: textSize.width + dotWidth + chipPaddingPt * 2,
            height: textSize.height + chipPaddingPt
        )
        let corner = transform.toView(SIMD2<Double>(cluster.bounds.minX, cluster.bounds.minY))
        let origin = CGPoint(x: corner.x - chipOffsetPt, y: corner.y - chipOffsetPt - chipSize.height)
        let rect = CGRect(origin: origin, size: chipSize)
        context.fill(Path(roundedRect: rect, cornerRadius: Radius.s), with: .color(Palette.surface))

        var textX = rect.minX + chipPaddingPt
        if let color = cluster.categoryColor {
            let dot = CGRect(
                x: textX,
                y: rect.midY - dotDiameterPt / 2,
                width: dotDiameterPt,
                height: dotDiameterPt
            )
            context.fill(Path(ellipseIn: dot), with: .color(color.swiftUIColor))
            textX += dotDiameterPt + chipPaddingPt
        }
        context.draw(label, at: CGPoint(x: textX, y: rect.midY), anchor: .leading)
    }
}

#Preview("Group overlay chips and outlines") {
    Canvas { context, _ in
        let transform = CanvasTransform(scale: 10, offset: SIMD2<Double>(50, 50))
        let clusters = [
            GroupClusterDisplay(
                label: "A · 112",
                bounds: BoundingBox(minX: 2, maxX: 12, minY: 2, maxY: 8),
                categoryColor: LegendColor(red: 0.16, green: 0.87, blue: 0.19),
                isSelected: true,
                isHovered: false
            ),
            GroupClusterDisplay(
                label: "B",
                bounds: BoundingBox(minX: 16, maxX: 26, minY: 2, maxY: 8),
                categoryColor: LegendColor(red: 0.87, green: 0.16, blue: 0.16),
                isSelected: false,
                isHovered: true
            )
        ]
        GroupOverlayRenderer.draw(clusters, in: &context, transform: transform)
    }
    .frame(width: 400, height: 200)
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

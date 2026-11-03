import SwiftUI
import simd

enum SelectionDimensionRenderer {
    static let minimumScale = 8.0
    private static let edgeGapPt: CGFloat = 10
    private static let dragChipGapPt: CGFloat = 16
    private static let chipPaddingPt: CGFloat = 4

    private enum LabelSide {
        case above
        case leftOf
    }

    static func drawDimensions(
        for object: LayoutObject,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        guard transform.scale >= minimumScale else { return }
        let size = object.placement.sizeM
        let widthText = object.kind == .pillar
            ? "⌀ \(DimensionInput.text(for: size.x)) m"
            : "\(DimensionInput.text(for: size.x)) m"
        drawLabel(widthText, side: .above, of: object.placement, in: &context, transform: transform)
        guard object.kind != .pillar, object.kind != .door else { return }
        let lengthText = "\(DimensionInput.text(for: size.y)) m"
        drawLabel(lengthText, side: .leftOf, of: object.placement, in: &context, transform: transform)
    }

    static func drawDragOffset(
        _ delta: SIMD2<Double>,
        near viewPoint: CGPoint,
        in context: inout GraphicsContext
    ) {
        let text = "Δ \(signedText(delta.x)) m, \(signedText(delta.y)) m"
        drawSizeChip(text, near: viewPoint, in: &context)
    }

    static func drawSizeChip(
        _ text: String,
        near viewPoint: CGPoint,
        in context: inout GraphicsContext
    ) {
        let origin = CGPoint(x: viewPoint.x + dragChipGapPt, y: viewPoint.y + dragChipGapPt)
        drawChip(text, topLeading: origin, in: &context)
    }

    private static func drawLabel(
        _ text: String,
        side: LabelSide,
        of placement: Placement,
        in context: inout GraphicsContext,
        transform: CanvasTransform
    ) {
        let size = placement.sizeM
        let local = side == .above ? SIMD2<Double>(0, -size.y / 2) : SIMD2<Double>(-size.x / 2, 0)
        let anchor = transform.toView(LayoutGeometry.toWorld(local: local, in: placement))
        var rotated = context
        rotated.translateBy(x: anchor.x, y: anchor.y)
        rotated.rotate(by: .radians(placement.rotationRadians))
        let chipSize = chipSize(for: text, in: rotated)
        let origin = side == .above
            ? CGPoint(x: -chipSize.width / 2, y: -edgeGapPt - chipSize.height)
            : CGPoint(x: -edgeGapPt - chipSize.width, y: -chipSize.height / 2)
        drawChip(text, topLeading: origin, in: &rotated)
    }

    private static func chipSize(for text: String, in context: GraphicsContext) -> CGSize {
        let measured = context.resolve(label(text)).measure(in: CGSize(width: 240, height: 40))
        return CGSize(width: measured.width + chipPaddingPt * 2, height: measured.height + chipPaddingPt)
    }

    private static func drawChip(_ text: String, topLeading: CGPoint, in context: inout GraphicsContext) {
        let size = chipSize(for: text, in: context)
        let rect = CGRect(origin: topLeading, size: size)
        context.fill(Path(roundedRect: rect, cornerRadius: Radius.s), with: .color(Palette.surface))
        context.draw(label(text), at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    private static func label(_ text: String) -> Text {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(Palette.textPrimary)
    }

    private static func signedText(_ value: Double) -> String {
        let magnitude = DimensionInput.text(for: abs(value))
        return value < 0 && magnitude != "0" ? "−\(magnitude)" : magnitude
    }
}

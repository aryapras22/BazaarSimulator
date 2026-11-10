import SwiftUI

struct FootprintThumbnail: View {
    let footprint: CatalogFootprint
    let sizeM: SIMD2<Double>
    let openSides: OpenSides
    let seats: [SIMD2<Double>]
    let tint: Color?

    init(
        footprint: CatalogFootprint,
        sizeM: SIMD2<Double>,
        openSides: OpenSides = [],
        seats: [SIMD2<Double>] = [],
        tint: Color? = nil
    ) {
        self.footprint = footprint
        self.sizeM = sizeM
        self.openSides = openSides
        self.seats = seats
        self.tint = tint
    }

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2.0, y: canvasSize.height / 2.0)
            let paddedW = sizeM.x + 1.4
            let paddedD = sizeM.y + 1.4
            let scale = min((canvasSize.width - 20) / paddedW, (canvasSize.height - 20) / paddedD)

            let widthPts = sizeM.x * scale
            let depthPts = sizeM.y * scale
            let rect = CGRect(
                x: center.x - widthPts / 2.0,
                y: center.y - depthPts / 2.0,
                width: widthPts,
                height: depthPts
            )

            drawFootprint(context: &context, rect: rect)
            drawOpenSides(context: &context, rect: rect)
            drawFaceMarker(context: &context, rect: rect)
            drawSeats(context: &context, center: center, scale: scale)
        }
        .frame(width: 120, height: 90)
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(Palette.surfaceBorder, lineWidth: 1)
        )
    }

    private func drawFootprint(context: inout GraphicsContext, rect: CGRect) {
        let fillColor = tint?.opacity(0.25) ?? Palette.background
        let strokeColor = tint ?? Palette.textSecondary

        if footprint == .circle {
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(fillColor))
            context.stroke(path, with: .color(strokeColor), lineWidth: 1.5)
        } else {
            let path = Path(rect)
            context.fill(path, with: .color(fillColor))
            context.stroke(path, with: .color(strokeColor), lineWidth: 1.5)
        }
    }

    private func drawOpenSides(context: inout GraphicsContext, rect: CGRect) {
        guard !openSides.isEmpty else { return }
        let stripThickness: CGFloat = 3.0

        for side in OpenSides.ordered where openSides.contains(side) {
            let stripRect: CGRect
            switch side {
            case .top:
                stripRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: stripThickness)
            case .bottom:
                stripRect = CGRect(
                    x: rect.minX, y: rect.maxY - stripThickness,
                    width: rect.width, height: stripThickness
                )
            case .left:
                stripRect = CGRect(x: rect.minX, y: rect.minY, width: stripThickness, height: rect.height)
            default: // .right
                stripRect = CGRect(
                    x: rect.maxX - stripThickness, y: rect.minY,
                    width: stripThickness, height: rect.height
                )
            }
            context.fill(Path(stripRect), with: .color(Palette.canvasOpenSide))
        }
    }

    private func drawFaceMarker(context: inout GraphicsContext, rect: CGRect) {
        guard footprint == .rect else { return }
        let markerWidth: CGFloat = 8.0
        let markerHeight: CGFloat = 5.0
        let startX = rect.midX - markerWidth / 2.0
        let endX = rect.midX + markerWidth / 2.0
        let baseY = rect.maxY + 1.0
        let tipY = baseY + markerHeight

        var triangle = Path()
        triangle.move(to: CGPoint(x: startX, y: baseY))
        triangle.addLine(to: CGPoint(x: endX, y: baseY))
        triangle.addLine(to: CGPoint(x: rect.midX, y: tipY))
        triangle.closeSubpath()

        context.fill(triangle, with: .color(Palette.textSecondary))
    }

    private func drawSeats(context: inout GraphicsContext, center: CGPoint, scale: Double) {
        let radius: CGFloat = 2.6
        for seat in seats {
            let seatPoint = CGPoint(
                x: center.x + seat.x * scale,
                y: center.y + seat.y * scale
            )
            let seatRect = CGRect(
                x: seatPoint.x - radius,
                y: seatPoint.y - radius,
                width: radius * 2.0,
                height: radius * 2.0
            )
            context.fill(Path(ellipseIn: seatRect), with: .color(Palette.textSecondary))
        }
    }
}

import SwiftUI

struct CanvasOverlays: View {
    let pointer: CanvasPointer
    let pointsPerMetre: Double
    let trailingInset: CGFloat
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                CanvasCursorReadout(pointer: pointer)
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.s) {
                    CanvasZoomControls(onZoomIn: onZoomIn, onZoomOut: onZoomOut, onFit: onFit)
                    CanvasScaleBar(pointsPerMetre: pointsPerMetre)
                }
            }
            .padding(.leading, CanvasRulers.leftWidth + Spacing.l)
            .padding(.trailing, trailingInset + Spacing.l)
            .padding(.bottom, Spacing.l)
        }
    }
}

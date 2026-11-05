import SwiftUI

struct CanvasOverlays: View {
    let pointer: CanvasPointer
    let pointsPerMetre: Double
    var tool: EditorTool = .select
    var message: String?
    var showReadouts: Bool = true
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if showReadouts {
                        CanvasCursorReadout(pointer: pointer)
                    }
                    EditorHintStrip(tool: tool, message: message)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.s) {
                    CanvasZoomControls(onZoomIn: onZoomIn, onZoomOut: onZoomOut, onFit: onFit)
                    if showReadouts {
                        CanvasScaleBar(pointsPerMetre: pointsPerMetre)
                    }
                }
            }
            .padding(.leading, CanvasRulers.leftWidth + Spacing.l)
            .padding(.trailing, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
    }
}

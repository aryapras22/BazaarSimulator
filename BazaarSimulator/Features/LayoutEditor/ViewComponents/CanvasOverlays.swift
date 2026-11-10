import SwiftUI

struct CanvasOverlays: View {
    let pointer: CanvasPointer
    let pointsPerMetre: Double
    var tool: EditorTool = .select
    var message: String?
    var showReadouts: Bool = true
    /// The swatches are hidden while the canvas has one fixed background; set this to bring the choice back.
    var showsBackgroundPicker = false
    @Binding var background: CanvasBackground
    var showsAttractiveness: Binding<Bool>?
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
                GlassEffectContainer(spacing: Spacing.s) {
                    VStack(alignment: .trailing, spacing: Spacing.s) {
                        if showReadouts {
                            if let showsAttractiveness {
                                AttractivenessLegend(isOn: showsAttractiveness)
                            }
                            if showsBackgroundPicker {
                                CanvasBackgroundSwatches(selection: $background)
                            }
                        }
                        CanvasZoomControls(onZoomIn: onZoomIn, onZoomOut: onZoomOut, onFit: onFit)
                        if showReadouts {
                            CanvasScaleBar(pointsPerMetre: pointsPerMetre)
                        }
                    }
                }
            }
            .padding(.leading, CanvasRulers.leftWidth + Spacing.l)
            .padding(.trailing, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
    }
}

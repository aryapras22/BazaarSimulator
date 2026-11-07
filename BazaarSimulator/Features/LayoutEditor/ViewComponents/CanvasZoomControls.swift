import SwiftUI

struct CanvasZoomControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            zoomButton("Zoom in", systemImage: "plus", help: "Zoom in (⌘=)", action: onZoomIn)
            zoomButton("Zoom out", systemImage: "minus", help: "Zoom out (⌘-)", action: onZoomOut)
            zoomButton(
                "Zoom to fit",
                systemImage: "arrow.up.left.and.arrow.down.right",
                help: "Zoom to fit (⌘0)",
                action: onFit
            )
        }
    }

    private func zoomButton(
        _ title: String,
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }
}

#Preview("Zoom controls") {
    GlassEffectContainer(spacing: Spacing.s) {
        CanvasZoomControls(onZoomIn: {}, onZoomOut: {}, onFit: {})
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}

import SwiftUI

struct CanvasZoomControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            zoomButton("+", accessibilityLabel: "Zoom in", action: onZoomIn)
            zoomButton("−", accessibilityLabel: "Zoom out", action: onZoomOut)
            zoomButton("fit", accessibilityLabel: "Zoom to fit", action: onFit)
        }
    }

    private func zoomButton(_ title: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Palette.surface))
                .overlay(Circle().stroke(Palette.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Zoom controls") {
    CanvasZoomControls(onZoomIn: {}, onZoomOut: {}, onFit: {})
        .padding()
        .background(Palette.background)
        .preferredColorScheme(.dark)
}

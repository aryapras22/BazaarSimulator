import SwiftUI

struct CanvasZoomControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onFit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            zoomButton("Zoom in", systemImage: "plus", help: "Zoom in (⌘=)", action: onZoomIn)
            zoomButton("Zoom out", systemImage: "minus", help: "Zoom out (⌘-)", action: onZoomOut)
            Button(action: onFit) {
                FitIcon()
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Zoom to fit (⌘0)")
            .accessibilityLabel("Zoom to fit")
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

/// The fit icon: a rounded square with a small triangle pointing in from each corner.
private struct FitIcon: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let tri = side * 0.26
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                    .stroke(lineWidth: max(side * 0.11, 1.5))
                    .frame(width: side * 0.52, height: side * 0.52)
                ForEach(0..<4, id: \.self) { corner in
                    CornerTriangle()
                        .frame(width: tri, height: tri)
                        .rotationEffect(.degrees(Double(corner) * 90))
                        .offset(
                            x: (corner == 0 || corner == 3 ? -1 : 1) * (side - tri) / 2,
                            y: (corner < 2 ? -1 : 1) * (side - tri) / 2
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }
}

/// A right triangle with its square corner at the top left, pointing at the middle of the icon.
private struct CornerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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

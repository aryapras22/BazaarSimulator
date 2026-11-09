import SwiftUI
import simd

/// A 2D floor plan canvas that renders the venue layout overlaid with the simulation crowd density heatmap.
struct LayoutHeatmapCanvas: View {
    let layout: Layout
    let densityCells: [DensityCell]
    var showHeatmap = true

    var body: some View {
        GeometryReader { geometry in
            let margin: CGFloat = 24
            let worldW = CGFloat(max(1.0, layout.sizeM.x))
            let worldH = CGFloat(max(1.0, layout.sizeM.y))
            let scale = min(
                (geometry.size.width - margin * 2) / worldW,
                (geometry.size.height - margin * 2) / worldH
            )
            let origin = CGPoint(
                x: (geometry.size.width - worldW * scale) / 2,
                y: (geometry.size.height - worldH * scale) / 2
            )

            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Palette.background)
                )

                drawFloor(in: &context, origin: origin, scale: scale)
                drawObjects(in: &context, origin: origin, scale: scale)

                if showHeatmap {
                    drawHeatmap(in: &context, origin: origin, scale: scale)
                    drawHotspots(in: &context, origin: origin, scale: scale)
                }
            }
        }
    }

    // MARK: - Drawing Helpers

    private func toScreen(_ point: SIMD2<Double>, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + CGFloat(point.x) * scale,
            y: origin.y + CGFloat(point.y) * scale
        )
    }

    private func drawFloor(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let floorFill = Color(red: 0.12, green: 0.15, blue: 0.23)
        let lobbyFill = Color(red: 0.10, green: 0.13, blue: 0.20)

        if layout.hall.count >= 3 {
            let hallPath = polygonPath(layout.hall, origin: origin, scale: scale)
            context.fill(hallPath, with: .color(floorFill))
            context.stroke(hallPath, with: .color(Palette.surfaceBorder), lineWidth: 1.5)
        } else {
            let rect = CGRect(
                x: origin.x,
                y: origin.y,
                width: CGFloat(layout.sizeM.x) * scale,
                height: CGFloat(layout.sizeM.y) * scale
            )
            context.fill(Path(rect), with: .color(floorFill))
            context.stroke(Path(rect), with: .color(Palette.surfaceBorder), lineWidth: 1.5)
        }

        if layout.lobby.count >= 3 {
            let lobbyPath = polygonPath(layout.lobby, origin: origin, scale: scale)
            context.fill(lobbyPath, with: .color(lobbyFill))
            context.stroke(lobbyPath, with: .color(Palette.surfaceBorder), lineWidth: 1.5)
        }
    }

    private func drawObjects(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        for object in layout.objects {
            let center = toScreen(object.placement.center, origin: origin, scale: scale)
            let width = CGFloat(object.placement.sizeM.x) * scale
            let height = CGFloat(object.placement.sizeM.y) * scale
            let rect = CGRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )

            switch object.kind {
            case .booth:
                let boothColor = Color(red: 0.25, green: 0.48, blue: 0.78).opacity(0.65)
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(boothColor))
                context.stroke(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(.white.opacity(0.35)),
                    lineWidth: 0.7
                )
            case .table:
                context.fill(Path(ellipseIn: rect), with: .color(Color.gray.opacity(0.5)))
            case .stage:
                let stageColor = Color.purple.opacity(0.45)
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(stageColor))
            case .door:
                let doorColor: Color = object.doorFlow?.direction == .exit ? .red : .green
                context.fill(Path(rect), with: .color(doorColor.opacity(0.85)))
            case .wall, .pillar, .closedArea, .block, .fixture, .rail:
                context.fill(Path(rect), with: .color(Color.white.opacity(0.20)))
            case .audienceArea:
                context.stroke(Path(rect), with: .color(Color.purple.opacity(0.3)), lineWidth: 1)
            }
        }
    }

    private func drawHeatmap(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let cellSpan = CGFloat(2.0) * scale

        for cell in densityCells {
            let center = toScreen(cell.center, origin: origin, scale: scale)
            let rect = CGRect(
                x: center.x - cellSpan / 2,
                y: center.y - cellSpan / 2,
                width: cellSpan,
                height: cellSpan
            )
            let density = cell.peoplePerSquareMetre
            let color: Color
            if density >= 0.72 {
                color = .red
            } else if density >= 0.30 {
                color = .orange
            } else {
                color = .green
            }

            let alpha = min(0.75, max(0.22, density / 1.4))
            context.fill(
                Path(roundedRect: rect, cornerRadius: 3),
                with: .color(color.opacity(alpha))
            )
        }
    }

    private func drawHotspots(in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let findings = SimulationAnalysis.bottlenecks(from: densityCells)
        for finding in findings {
            let center = toScreen(finding.point, origin: origin, scale: scale)
            let radius: CGFloat = max(6, min(12, scale * 0.6))
            let circleRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let ringColor: Color = finding.density >= 0.72 ? .red : .orange
            context.stroke(Path(ellipseIn: circleRect), with: .color(ringColor), lineWidth: 2.0)
        }
    }

    private func polygonPath(_ points: [SIMD2<Double>], origin: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: toScreen(first, origin: origin, scale: scale))
        for point in points.dropFirst() {
            path.addLine(to: toScreen(point, origin: origin, scale: scale))
        }
        path.closeSubpath()
        return path
    }
}

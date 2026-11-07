import SwiftUI

/// The floor plan with what the simulation shows over it: grades at the busiest spots, crowd
/// density, or the most walked paths, and the visitors themselves.
struct SimulationPlanView: View {
    @Bindable var viewModel: SimulationPlayerViewModel
    let time: Double

    var body: some View {
        if let layout = viewModel.layout, let outcome = viewModel.outcome {
            LayoutPlanCanvas(layout: layout, plan: viewModel.plan)
                .equatable()
                .aspectRatio(viewModel.planAspect, contentMode: .fit)
                .overlay {
                    Canvas { context, size in
                        switch viewModel.mode {
                        case .congestion: drawGlows(in: &context, size: size, outcome: outcome)
                        case .density: drawDensity(in: &context, size: size)
                        case .footfall: drawFootfall(in: &context, size: size)
                        }
                        drawVisitors(in: &context, size: size)
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    if viewModel.mode == .congestion { markers(outcome: outcome) }
                }
                .overlay {
                    HotspotOverlay(
                        layout: viewModel.layoutID,
                        outcome: outcome,
                        hovered: $viewModel.hoveredSpot,
                        showsCallout: false,
                        showsMarkers: false
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(
                    "\(viewModel.layoutID.name) with \(viewModel.visitorsInside(at: time)) visitors"
                )
        }
    }

    private var progress: Double { viewModel.progress(at: time) }

    private func markers(outcome: LayoutOutcome) -> some View {
        GeometryReader { geometry in
            ForEach(outcome.spots, id: \.number) { spot in
                SpotMarker(number: spot.number, grade: .grade(forDensity: spot.density(at: progress)))
                    .fixedSize()
                    .frame(width: 0, height: 0, alignment: .leading)
                    .offset(x: -SpotMarker.circleSize / 2)
                    .position(x: spot.location.x * geometry.size.width, y: spot.location.y * geometry.size.height)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawVisitors(in context: inout GraphicsContext, size: CGSize) {
        let radius = max(size.width / 260, 3)
        let colors = Palette.visitorSeriesColors
        for visitor in viewModel.visitors(at: time) {
            let grown = radius * (1 + 0.12 * Double(max(visitor.people - 1, 0)))
            let center = CGPoint(x: visitor.point.x * size.width, y: visitor.point.y * size.height)
            let dot = Path(ellipseIn: CGRect(x: center.x - grown, y: center.y - grown, width: grown * 2, height: grown * 2))
            context.fill(dot, with: .color(colors[visitor.typeIndex % colors.count]))
            context.stroke(dot, with: .color(.visitorOutline), lineWidth: 1.2)
        }
    }

    private func drawDensity(in context: inout GraphicsContext, size: CGSize) {
        let columns = SimulationPlayerViewModel.heatColumns, rows = viewModel.heatRows
        let density = viewModel.heatDensity(at: time)
        let cell = CGSize(width: size.width / CGFloat(columns), height: size.height / CGFloat(rows))
        var heat = context
        heat.clip(to: viewModel.walkablePath.applying(CGAffineTransform(scaleX: size.width, y: size.height)))
        heat.drawLayer { layer in
            layer.addFilter(.blur(radius: cell.width * 1.1))
            for row in 0..<rows {
                for column in 0..<columns {
                    let value = density[row * columns + column]
                    guard value > 0 else { continue }
                    let level = HeatScale.level(forDensity: value)
                    let rect = CGRect(x: CGFloat(column) * cell.width, y: CGFloat(row) * cell.height, width: cell.width, height: cell.height)
                    layer.fill(
                        Path(rect.insetBy(dx: -cell.width * 0.3, dy: -cell.height * 0.3)),
                        with: .color(HeatScale.color(forLevel: level).opacity(0.4 + 0.45 * level))
                    )
                }
            }
        }
    }

    private func drawGlows(in context: inout GraphicsContext, size: CGSize, outcome: LayoutOutcome) {
        let scale = size.width / 686.5
        for spot in outcome.spots {
            let level = min(spot.density(at: progress) / SeverityGrade.f.lowerDensity, 1)
            let radius = 36 * scale * (0.8 + 0.4 * level)
            let center = CGPoint(x: spot.location.x * size.width, y: spot.location.y * size.height)
            let glow = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.fill(glow, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color.spotGlow.opacity(0.8), location: 0),
                    .init(color: Color.spotGlow.opacity(0.45), location: 0.5),
                    .init(color: Color.spotGlow.opacity(0), location: 1)
                ]),
                center: center, startRadius: 0, endRadius: radius
            ))
        }
    }

    private func drawFootfall(in context: inout GraphicsContext, size: CGSize) {
        guard let replay = viewModel.replay else { return }
        let counts = viewModel.footfall(at: time)
        let busiest = Double(counts.max() ?? 1)
        let plan = viewModel.plan
        let tile = CGSize(
            width: replay.footfallTileM / plan.size.x * size.width,
            height: replay.footfallTileM / plan.size.y * size.height
        )
        var paths = context
        paths.clip(to: viewModel.walkablePath.applying(CGAffineTransform(scaleX: size.width, y: size.height)))
        paths.drawLayer { layer in
            layer.addFilter(.blur(radius: tile.width * 0.6))
            for index in counts.indices where counts[index] > 0 {
                let share = Double(counts[index]) / max(busiest, 1)
                let rect = CGRect(
                    x: CGFloat(index % replay.footfallColumns) * tile.width,
                    y: CGFloat(index / replay.footfallColumns) * tile.height,
                    width: tile.width, height: tile.height
                )
                layer.fill(Path(rect), with: .color(HeatScale.color(forLevel: share).opacity(0.85)))
            }
        }
    }
}

struct SpotMarker: View {
    static let circleSize: CGFloat = 19

    let number: Int
    let grade: SeverityGrade

    var body: some View {
        HStack(spacing: 0) {
            SpotNumber(number: number, size: Self.circleSize, isCircle: true)
            Rectangle()
                .fill(.black)
                .frame(width: 28.5, height: 1)
            Text("Grade \(grade.letter)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .frame(height: 25.5)
                .background(grade.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}

struct SpotNumber: View {
    let number: Int
    var size: CGFloat = 28.5
    var isCircle = false

    var body: some View {
        Text("\(number)")
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                if isCircle {
                    Circle().fill(.black).overlay { Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1) }
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.black)
                }
            }
    }
}

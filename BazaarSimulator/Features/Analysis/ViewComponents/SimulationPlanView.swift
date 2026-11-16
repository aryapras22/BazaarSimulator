import SwiftUI

/// The floor plan in 2D using SpriteKit (`Simulation2DSpriteView`), with the simulation overlay modes:
/// congestion spots, Gaussian KDE crowd density, or cumulative walked paths, plus moving visitors.
struct SimulationPlanView: View {
    @Bindable var viewModel: SimulationPlayerViewModel
    let time: Double

    var body: some View {
        if let layout = viewModel.layout, let outcome = viewModel.outcome {
            Simulation2DSpriteView(
                layout: layout,
                visitors: viewModel.spriteVisitors(at: time),
                densityCells: viewModel.spriteOverlayCells(at: time),
                showHeatmap: true
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func markers(outcome: LayoutOutcome) -> some View {
        GeometryReader { geometry in
            ForEach(outcome.spots, id: \.number) { spot in
                SpotMarker(
                    number: spot.number,
                    grade: .grade(forDensity: viewModel.spotDensity(for: spot, at: time))
                )
                .fixedSize()
                .frame(width: 0, height: 0, alignment: .leading)
                .offset(x: -SpotMarker.circleSize / 2)
                .position(x: spot.location.x * geometry.size.width, y: spot.location.y * geometry.size.height)
            }
        }
        .allowsHitTesting(false)
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

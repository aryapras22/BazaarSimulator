import SwiftUI
import simd

/// The floor plan in 2D using SpriteKit (`Simulation2DSpriteView`), with the simulation overlay modes:
/// congestion spots, Gaussian KDE crowd density, or cumulative walked paths, plus moving visitors.
struct SimulationPlanView: View {
    @Bindable var viewModel: SimulationPlayerViewModel
    let time: Double

    @State private var cameraTransform = SpriteCameraTransform()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let layout = viewModel.layout, let outcome = viewModel.outcome {
            Simulation2DSpriteView(
                layout: layout,
                visitors: viewModel.spriteVisitors(at: time),
                densityCells: viewModel.spriteOverlayCells(at: time),
                showHeatmap: true,
                onCameraChange: { transform in
                    if cameraTransform != transform {
                        cameraTransform = transform
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if viewModel.mode == .congestion {
                    markers(outcome: outcome, layout: layout)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(
                "\(viewModel.layoutID.name) with \(viewModel.visitorsInside(at: time)) visitors"
            )
        }
    }

    private func markers(outcome: LayoutOutcome, layout: Layout) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(outcome.spots, id: \.number) { spot in
                    let point = spotViewPosition(for: spot, in: layout, viewSize: geometry.size)
                    SpotMarker(
                        number: spot.number,
                        grade: .grade(forDensity: viewModel.spotDensity(for: spot, at: time))
                    )
                    .fixedSize()
                    .frame(width: 0, height: 0, alignment: .leading)
                    .offset(x: -SpotMarker.circleSize / 2)
                    .position(point)
                    .allowsHitTesting(false)

                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 28, height: 28)
                        .position(point)
                        .onHover { inside in
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                                if inside {
                                    viewModel.hoveredSpot = spot.number
                                } else if viewModel.hoveredSpot == spot.number {
                                    viewModel.hoveredSpot = nil
                                }
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    private func spotViewPosition(for spot: SpotOutcome, in layout: Layout, viewSize: CGSize) -> CGPoint {
        let plan = viewModel.plan
        let pointM = SIMD2<Double>(
            plan.origin.x + Double(spot.location.x) * plan.size.x,
            plan.origin.y + Double(spot.location.y) * plan.size.y
        )
        return cameraTransform.swiftUIPoint(for: pointM, in: layout, fallbackSize: viewSize)
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

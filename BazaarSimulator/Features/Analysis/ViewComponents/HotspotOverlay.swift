import SwiftUI

struct HotspotOverlay: View {
    let layout: LayoutID
    let outcome: LayoutOutcome
    @Binding var hovered: Int?
    var showsCallout = true
    var showsMarkers = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack(alignment: .topLeading) {
                ForEach(outcome.spots, id: \.number) { spot in
                    let center = CGPoint(
                        x: spot.location.x * size.width,
                        y: spot.location.y * size.height
                    )
                    HotspotTarget(
                        number: spot.number,
                        grade: showsMarkers ? spot.grade : nil,
                        isHovered: hovered == spot.number,
                        diameter: min(max(size.width * 0.05, 14), 18)
                    )
                    .position(center)
                    .onHover { inside in
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                            if inside {
                                hovered = spot.number
                            } else if hovered == spot.number {
                                hovered = nil
                            }
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Spot \(spot.number), \(spot.name)")
                    .accessibilityValue("Grade \(spot.grade.letter), \(spot.peakDensity.formatted(.number.precision(.fractionLength(1)))) people per square metre at peak. \(spot.cause)")
                }

                if showsCallout,
                   let spot = outcome.spots.first(where: { $0.number == hovered }) {
                    HotspotCallout(spot: spot)
                        .fixedSize()
                        .alignmentGuide(.leading) { card in
                            let x = spot.location.x * size.width
                            return spot.location.x < 0.5 ? -(x + 20) : card.width - x + 20
                        }
                        .alignmentGuide(.top) { card in
                            let y = spot.location.y * size.height
                            return spot.location.y < 0.5 ? -(y + 16) : card.height - y + 16
                        }
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(1)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }
}

private struct HotspotTarget: View {
    let number: Int
    let grade: SeverityGrade?
    let isHovered: Bool
    let diameter: CGFloat

    var body: some View {
        ZStack {
            if let grade {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color.hotspotSevere.opacity(0.85), location: 0),
                                .init(color: Color.hotspotSevere.opacity(0.45), location: 0.55),
                                .init(color: Color.hotspotSevere.opacity(0), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter * 1.3
                        )
                    )
                    .frame(width: diameter * 2.6, height: diameter * 2.6)
                    .allowsHitTesting(false)
                Circle()
                    .fill(grade.color)
                    .overlay {
                        Text("\(number)")
                            .font(.system(size: diameter * 0.58, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay {
                        Circle().strokeBorder(
                            .white.opacity(isHovered ? 1 : 0.85),
                            lineWidth: isHovered ? 2 : 1.25
                        )
                    }
                    .frame(width: diameter, height: diameter)
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(isHovered ? 0.95 : 0), lineWidth: 2)
                    .background(Circle().fill(Color.hotspotSevere.opacity(isHovered ? 0.25 : 0.001)))
                    .frame(width: diameter * 1.6, height: diameter * 1.6)
            }
        }
        .scaleEffect(isHovered ? 1.15 : 1)
        .frame(width: diameter * 1.6, height: diameter * 1.6)
        .contentShape(Circle())
        .pointerStyle(.link)
    }
}

struct HotspotCallout: View {
    let spot: SpotOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(spot.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .fixedSize()
                Spacer(minLength: 12)
                GradePill(grade: spot.grade)
            }

            SpotStats(spot: spot, valueSize: 20)

            Text(spot.cause)
                .font(.system(size: 12))
                .foregroundStyle(.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(minWidth: 300, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.backgroundMain.opacity(0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        }
    }
}

struct GradePill: View {
    let grade: SeverityGrade

    var body: some View {
        Text("\(grade.letter) · \(grade.title)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(grade.color, in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.75) }
            .fixedSize()
            .help("Grade \(grade.letter): \(grade.meaning)")
    }
}

struct SpotStats: View {
    let spot: SpotOutcome
    var valueSize: CGFloat = 20
    var inline = false

    var body: some View {
        HStack(alignment: inline ? .firstTextBaseline : .top, spacing: inline ? 14 : 18) {
            stat(spot.peakDensity.formatted(.number.precision(.fractionLength(1))), "per m²")
            stat("\(formatMinutes(spot.stuckMin)) min", "stuck")
            stat("\(spot.peakVisitors)", "people at once")
        }
        .fixedSize()
    }

    @ViewBuilder
    private func stat(_ value: String, _ label: String) -> some View {
        let number = Text(value)
            .font(.system(size: valueSize, weight: .semibold))
            .foregroundStyle(.textPrimary)
            .monospacedDigit()
        let caption = Text(label)
            .font(.system(size: 11))
            .foregroundStyle(.textSecondary)
        if inline {
            HStack(alignment: .firstTextBaseline, spacing: 4) { number; caption }
        } else {
            VStack(alignment: .leading, spacing: 1) { number; caption }
        }
    }

    private func formatMinutes(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return rounded.formatted(.number.precision(.fractionLength(1)))
    }
}

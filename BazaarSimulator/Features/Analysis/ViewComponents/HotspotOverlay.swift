import SwiftUI

struct HotspotOverlay: View {
    let layout: LayoutID
    let outcome: LayoutOutcome
    @Binding var hovered: Int?
    var showsCallout = true
    var showsMarkers = true

    /// A click keeps one spot's details open after the pointer moves away.
    @State private var pinned: Int?
    @State private var calloutHeight: CGFloat = 110

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let gap: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let shown = pinned ?? hovered

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { animate { pinned = nil } }
                    .allowsHitTesting(pinned != nil)

                ForEach(outcome.spots, id: \.number) { spot in
                    HotspotTarget(
                        number: spot.number,
                        grade: showsMarkers ? spot.grade : nil,
                        isHovered: shown == spot.number,
                        diameter: min(max(size.width * 0.05, 14), 18)
                    )
                    // The handlers go on the marker itself, before it is positioned. After `position` they would
                    // belong to a view as big as the whole plan, so any hover or click on it would count.
                    .onHover { inside in
                        animate {
                            if inside {
                                hovered = spot.number
                            } else if hovered == spot.number {
                                hovered = nil
                            }
                        }
                    }
                    .onTapGesture { animate { pinned = pinned == spot.number ? nil : spot.number } }
                    .help(pinned == spot.number ? "Click to close" : "Hover to see the details, click to keep them open")
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Spot \(spot.number), \(spot.name)")
                    .accessibilityValue(
                        "Grade \(spot.grade.letter), \(spot.grade.title). \(HotspotCallout.summary(for: spot)) \(spot.cause)"
                    )
                    .position(center(of: spot, in: size))
                }

                if showsCallout, let spot = outcome.spots.first(where: { $0.number == shown }) {
                    HotspotCallout(spot: spot)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { calloutHeight = $0 }
                        .offset(x: calloutOrigin(for: spot, in: size).x, y: calloutOrigin(for: spot, in: size).y)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    private func center(of spot: SpotOutcome, in size: CGSize) -> CGPoint {
        CGPoint(x: spot.location.x * size.width, y: spot.location.y * size.height)
    }

    /// The box goes above or below the spot, or beside it, wherever it fits without covering another marker.
    private func calloutOrigin(for spot: SpotOutcome, in size: CGSize) -> CGPoint {
        let point = center(of: spot, in: size)
        let card = CGSize(width: HotspotCallout.width, height: calloutHeight)
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 6, dy: 6)
        let markers = outcome.spots.filter { $0.number != spot.number }
            .map { center(of: $0, in: size) }
            .map { CGRect(x: $0.x - 12, y: $0.y - 12, width: 24, height: 24) }
        let x = min(max(point.x - card.width / 2, bounds.minX), max(bounds.maxX - card.width, bounds.minX))
        let middleY = min(max(point.y - card.height / 2, bounds.minY), max(bounds.maxY - card.height, bounds.minY))
        let candidates = [
            CGPoint(x: x, y: point.y - Self.gap - card.height),
            CGPoint(x: x, y: point.y + Self.gap),
            CGPoint(x: point.x + Self.gap, y: middleY),
            CGPoint(x: point.x - Self.gap - card.width, y: middleY)
        ].map { CGRect(origin: $0, size: card) }
        let inside = candidates.filter { bounds.contains($0) }
        let best = inside.first { rect in !markers.contains { $0.intersects(rect) } } ?? inside.first ?? candidates[0]
        return best.origin
    }

    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15), change)
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
                                .init(color: grade.color, location: 0),
                                .init(color: grade.color.opacity(0.5), location: 0.55),
                                .init(color: grade.color.opacity(0), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter * 0.9
                        )
                    )
                    .frame(width: diameter * 2.0, height: diameter * 2.0)
                    .opacity(0.6)
                    .allowsHitTesting(false)

                Circle()
                    .fill(grade.color)
                    .overlay {
                        Text("\(number)")
                            .font(.system(size: diameter * 0.45, weight: .bold))
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
                    .background(Circle().fill(Color.gradeE.opacity(isHovered ? 0.25 : 0.001)))
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
    static let width: CGFloat = 250

    let spot: SpotOutcome

    /// One plain sentence about how long people are stuck here.
    static func summary(for spot: SpotOutcome) -> String {
        let minutes = (spot.stuckMin * 2).rounded() / 2
        guard minutes >= 0.25 else { return "People keep moving here." }
        let text = minutes == minutes.rounded()
            ? String(Int(minutes))
            : minutes.formatted(.number.precision(.fractionLength(1)))
        return "People get stuck here for \(text) min."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(spot.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 8)
                GradePill(grade: spot.grade)
            }
            Text(Self.summary(for: spot))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(spot.cause)
                .font(.system(size: 12))
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: Self.width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.backgroundMain.opacity(0.95))
                .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.3), lineWidth: 1) }
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

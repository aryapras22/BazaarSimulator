import SwiftUI

struct LayoutComparisonCard: View {
    let layout: LayoutID
    let outcome: LayoutOutcome
    var peakHourText: String = "14:00"
    var metrics: DashboardMetrics = .reference
    var onSimulate: () -> Void = {}
    var onEdit: () -> Void = {}

    @State private var hoveredSpot: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
                .padding(.horizontal, LayoutCardInset.horizontal)

            floorPlanImage
                .frame(height: metrics.planHeight)
                .frame(maxWidth: .infinity)
                .padding(.top, metrics.planTopPadding)
                .zIndex(1)

            footerDetails
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(
                    height: SeverityScaleView.labelHeight + SeverityScaleView.labelSpacing + SeverityScaleView.barHeight,
                    alignment: .bottom
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hoveredSpot)
                .padding(.leading, LayoutCardInset.legendLeading)
                .padding(.trailing, LayoutCardInset.legendTrailing)
                .padding(.top, 3)
        }
        .padding(.top, LayoutCardInset.top)
        .padding(.bottom, LayoutCardInset.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var headerBar: some View {
        HStack(spacing: 13) {
            Button {} label: {
                HStack(spacing: 9) {
                    Circle()
                        .fill(layout.accent)
                        .frame(width: 10, height: 10)
                    Text(layout.name)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.leading, 3)
                }
            }
            .buttonStyle(ControlButtonStyle(horizontalPadding: 11))
            .accessibilityLabel("Layout selector, \(layout.name)")

            Spacer(minLength: 8)

            Button(action: onSimulate) {
                Label("Simulate", systemImage: "play.fill")
                    .labelStyle(ControlLabelStyle())
            }
            .buttonStyle(ControlButtonStyle(horizontalPadding: 16))
            .help("Watch visitors move through \(layout.name)")

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .labelStyle(ControlLabelStyle())
            }
            .buttonStyle(ControlButtonStyle(horizontalPadding: 16))
        }
    }

    private var floorPlanImage: some View {
        Image(layout.floorPlanAssetName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .overlay {
                HotspotOverlay(
                    layout: layout,
                    outcome: outcome,
                    hovered: $hoveredSpot,
                    showsCallout: false
                )
            }
    }

    @ViewBuilder
    private var footerDetails: some View {
        if let spotNumber = hoveredSpot,
           let spot = outcome.spots.first(where: { $0.number == spotNumber }) {
            SpotDetailRow(spot: spot, peakHourText: peakHourText)
        } else {
            HStack(alignment: .bottom, spacing: 16) {
                SeverityScaleView()
                Spacer(minLength: 0)
                WorstSpotSummary(layout: layout, outcome: outcome, peakHourText: peakHourText)
            }
        }
    }
}

enum FloorPlan {
    static let aspectRatio: CGFloat = 370.0 / 425.0
}

private struct ControlLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 9) {
            configuration.icon
                .font(.system(size: 12, weight: .semibold))
            configuration.title
        }
    }
}

struct SeverityScaleView: View {
    static let labelHeight: CGFloat = 12
    static let labelSpacing: CGFloat = 7
    static let barHeight: CGFloat = 24
    static let cellWidth: CGFloat = 38

    var labelBelow = false
    var cellWidth = Self.cellWidth
    var barHeight = Self.barHeight
    var barRadius: CGFloat?
    var labelSpacing = Self.labelSpacing
    var letterSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: labelSpacing) {
            if labelBelow {
                bar
                label
            } else {
                label
                bar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Severity scale. Low: A to B. Medium: C to D. Severe: E to F.")
    }

    private var label: some View {
        Text("\(Text("Low").fontWeight(.semibold).foregroundStyle(.textPrimary)): A - B · \(Text("Medium").fontWeight(.semibold).foregroundStyle(.textPrimary)): C - D · \(Text("Severe").fontWeight(.semibold).foregroundStyle(.textPrimary)): E - F")
            .font(.system(size: 11))
            .foregroundStyle(.textSecondary)
            .fixedSize()
            .frame(height: Self.labelHeight)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(SeverityGrade.allCases) { grade in
                Text(grade.letter)
                    .font(.system(size: letterSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: cellWidth, height: barHeight)
                    .background(grade.color)
                    .help("Grade \(grade.letter) · \(grade.title): \(grade.rangeText) people per m². \(grade.meaning)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: barRadius ?? barHeight / 2, style: .continuous))
    }
}

private struct WorstSpotSummary: View {
    let layout: LayoutID
    let outcome: LayoutOutcome
    var peakHourText: String = "14:00"

    var body: some View {
        let worst = outcome.worstSpot
        let role = outcome.spotTotal == 1 ? "the only spot we check" : "the most crowded spot"
        let dText = worst.peakDensity.formatted(.number.precision(.fractionLength(1)))

        HStack(spacing: 9) {
            Text("Grade \(worst.grade.letter)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: SeverityScaleView.barHeight)
                .background(worst.grade.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("\(worst.name) (Spot \(worst.number))")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: SeverityScaleView.barHeight)
        .fixedSize()
        .help("\(worst.name) (Spot \(worst.number)) is \(role) at \(peakHourText): \(dText) people per m², grade \(worst.grade.letter) (\(worst.grade.title)). Hover the spots on the floor plan for details.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(role.prefix(1).uppercased() + role.dropFirst()) at \(peakHourText): \(worst.name), grade \(worst.grade.letter), \(worst.grade.title)")
    }
}

private struct SpotDetailRow: View {
    let spot: SpotOutcome
    var peakHourText: String = "14:00"

    var body: some View {
        VStack(alignment: .leading, spacing: SeverityScaleView.labelSpacing) {
            HStack(spacing: 6) {
                Text("Spot \(spot.number) · \(spot.name)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text("at \(peakHourText)")
                    .font(.system(size: 11))
                    .foregroundStyle(.textSecondary)
            }
            .frame(height: SeverityScaleView.labelHeight)
            HStack(spacing: 16) {
                GradePill(grade: spot.grade)
                SpotStats(spot: spot, valueSize: 14, inline: true)
            }
            .frame(height: SeverityScaleView.barHeight)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

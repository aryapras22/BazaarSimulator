import SwiftUI

struct LayoutComparisonCard: View {
    let layout: LayoutID
    let outcome: LayoutOutcome
    /// The layout and the part of it the plan shows, drawn behind the spots.
    var floorPlan: Layout?
    var plan: PlanFrame = .unit
    var peakHourText: String = "14:00"
    var metrics: DashboardMetrics = .reference
    /// Height of the floor plan. Left out, the metrics decide.
    var planHeight: CGFloat?
    /// Simulate is on every layout, also on a saved run, which plays its own layouts. A saved run has no Edit.
    var showsSimulate = true
    var showsEdit = true
    /// With one layout the card is the whole page, so it also names the worst spot under the plan.
    var showsWorstSpot = false
    var onSimulate: () -> Void = {}
    var onEdit: () -> Void = {}

    @State private var hoveredSpot: Int?
    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
                .padding(.horizontal, LayoutCardInset.horizontal)

            ZoomablePlan(zoom: $zoom) {
                floorPlanImage
            }
            .aspectRatio(planAspect, contentMode: .fit)
            .frame(height: max(planHeight ?? metrics.planHeight, 0))
            .frame(maxWidth: .infinity)
            .padding(.top, metrics.planTopPadding)
            .zIndex(1)

            HStack(alignment: .bottom, spacing: 16) {
                SeverityScaleView()
                Spacer(minLength: 0)
                if showsWorstSpot, !outcome.spots.isEmpty {
                    WorstSpotSummary(outcome: outcome, peakHourText: peakHourText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(
                height: SeverityScaleView.labelHeight + SeverityScaleView.labelSpacing + SeverityScaleView.barHeight,
                alignment: .bottom
            )
                .padding(.leading, LayoutCardInset.legendLeading)
                .padding(.trailing, LayoutCardInset.legendTrailing)
                .padding(.top, 3)
        }
        .padding(.top, LayoutCardInset.top)
        .padding(.bottom, LayoutCardInset.bottom)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        // The details box can reach past the card, so the card with an open box draws above its neighbour.
        .zIndex(hoveredSpot == nil ? 0 : 10)
    }

    private var planAspect: CGFloat {
        guard floorPlan != nil, plan.size.y > 0, plan.size.x > 0 else { return FloorPlan.aspectRatio }
        return CGFloat(plan.size.x / plan.size.y)
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

            ZoomControls(zoom: $zoom)

            if showsSimulate {
                Button(action: onSimulate) {
                    Label("Simulate", systemImage: "play.fill")
                        .labelStyle(ControlLabelStyle())
                }
                .buttonStyle(ControlButtonStyle())
                .help("Watch visitors move through \(layout.name)")
            }

            if showsEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(ControlLabelStyle())
                }
                .buttonStyle(ControlButtonStyle())
                .help("Change \(layout.name) in the layout editor")
            }
        }
    }

    private var floorPlanImage: some View {
        Group {
            if let floorPlan {
                LayoutPlanCanvas(layout: floorPlan, plan: plan)
                    .equatable()
            } else {
                Color.clear
            }
        }
        .overlay {
            HotspotOverlay(
                layout: layout,
                outcome: outcome,
                hovered: $hoveredSpot,
                showsCallout: true
            )
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
        .accessibilityLabel("Grade scale. A to B: calm. C to D: busy. E to F: people get stuck.")
    }

    private var label: some View {
        Text("\(Text("Calm").fontWeight(.semibold).foregroundStyle(.textPrimary)): A - B · \(Text("Busy").fontWeight(.semibold).foregroundStyle(.textPrimary)): C - D · \(Text("Stuck").fontWeight(.semibold).foregroundStyle(.textPrimary)): E - F")
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

/// The most crowded spot of a layout, named under its plan: its grade and where it is.
private struct WorstSpotSummary: View {
    let outcome: LayoutOutcome
    var peakHourText: String = "14:00"

    var body: some View {
        let worst = outcome.worstSpot
        let density = worst.peakDensity.formatted(.number.precision(.fractionLength(1)))
        HStack(spacing: 9) {
            Text("Grade \(worst.grade.letter)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: SeverityScaleView.barHeight)
                .background(worst.grade.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("\(worst.name) (Spot \(worst.number))")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(height: SeverityScaleView.barHeight)
        .fixedSize(horizontal: false, vertical: true)
        .help("\(worst.name) (Spot \(worst.number)) is the most crowded spot at \(peakHourText): \(density) people per m², grade \(worst.grade.letter) (\(worst.grade.title)).")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Most crowded spot at \(peakHourText): \(worst.name), grade \(worst.grade.letter), \(worst.grade.title)")
    }
}

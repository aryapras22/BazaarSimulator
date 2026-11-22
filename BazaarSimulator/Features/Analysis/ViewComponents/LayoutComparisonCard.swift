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
    /// The project's layouts this card can show instead. Empty when there is nothing to pick.
    var choices: [Layout] = []
    /// The project layout that is the best one, starred in the list of choices.
    var bestChoiceID: Layout.ID?
    var onChoose: (Layout.ID) -> Void = { _ in }
    var onSimulate: () -> Void = {}
    var onEdit: () -> Void = {}

    @State private var hoveredSpot: Int?
    @State private var showsChoices = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
                .padding(.horizontal, LayoutCardInset.horizontal)

            floorPlanImage
            .aspectRatio(planAspect, contentMode: .fit)
            .frame(height: max(planHeight ?? metrics.planHeight, 0))
            .frame(maxWidth: .infinity)
            .padding(.top, metrics.planTopPadding)
            .zIndex(1)

            // The row under the plan is only there for a single layout, which names its worst spot. With two layouts
            // the room goes to the plan.
            if showsWorstSpot {
                HStack(alignment: .bottom, spacing: 16) {
                    Spacer(minLength: 0)
                    if !outcome.spots.isEmpty {
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
        HStack(spacing: 6) {
            Button { showsChoices = true } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(layout.accent)
                        .frame(width: 10, height: 10)
                        .layoutPriority(1)
                    Text(layout.name)
                        .layoutPriority(1)
                    if let planName = floorPlan?.name, !planName.isEmpty {
                        Text(planName)
                            .foregroundStyle(.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if !choices.isEmpty {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.leading, 2)
                            .layoutPriority(1)
                    }
                }
            }
            .buttonStyle(ControlButtonStyle(horizontalPadding: 10, allowsTruncation: true))
            .allowsHitTesting(!choices.isEmpty)
            .help(choices.isEmpty ? "" : "Show another of the project's layouts here")
            .popover(isPresented: $showsChoices, arrowEdge: .bottom) { choiceList }
            .accessibilityLabel("Layout selector, \(layout.name)")

            Spacer(minLength: 0)

            if showsSimulate {
                Button(action: onSimulate) {
                    Label("Simulate", systemImage: "play.fill")
                        .labelStyle(ControlLabelStyle())
                }
                .buttonStyle(ControlButtonStyle(horizontalPadding: 12))
                .help("Watch visitors move through \(layout.name)")
            }

            if showsEdit {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(ControlLabelStyle())
                }
                .buttonStyle(ControlButtonStyle(horizontalPadding: 12))
                .help("Change \(layout.name) in the layout editor")
            }
        }
    }

    private var choiceList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(choices) { choice in
                Button {
                    showsChoices = false
                    onChoose(choice.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(choice.id == floorPlan?.id ? 1 : 0)
                        Text(choice.name.isEmpty ? "Untitled layout" : choice.name)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if choice.id == bestChoiceID {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.yellow)
                                .help("Best layout")
                                .accessibilityLabel("Best layout")
                        }
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(minWidth: 220)
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
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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

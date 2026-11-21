
import SwiftUI

struct BestLayoutSummaryView: View {
    let summary: BestLayoutSummary
    var onInsights: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                TrophyTile(layout: summary.best)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best layout")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                    // In the layout's own color, the same as its tile and chart line.
                    Text(summary.best.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(summary.best.chartColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 190, alignment: .leading)
            }
            .padding(.trailing, 22)
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                // The columns start at the same height, whether or not one has a note, and the row as a whole is
                // centered in the card.
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(summary.checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Rectangle()
                                .fill(Color.divider)
                                .frame(width: 1)
                                .padding(.vertical, 16)
                        }
                        CheckColumn(check: check, best: summary.best, caption: summary.caption(for: check))
                    }
                }
                // Only as tall as its tallest column, so the dividers match it and the row can be centered.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)

                whyRow
                    .padding(.leading, 18)
                    .padding(.top, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .frame(height: DashboardMetrics.summaryHeight)
        .cardSurface()
    }

    private var whyRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Why is \(summary.best.name) better?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text("Compare both layouts on stuck spots, crowd level and time stuck in Insights.")
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Insights", action: onInsights)
                .buttonStyle(ControlButtonStyle())
        }
    }
}

private struct TrophyTile: View {
    let layout: LayoutID

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let tint = layout.chartColor
        Image(systemName: "trophy.fill")
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 80, height: 80)
            .background(tint, in: shape)
            .accessibilityHidden(true)
    }
}

private struct CheckColumn: View {
    let check: BestLayoutSummary.Check
    let best: LayoutID
    let caption: String

    var body: some View {
        let mine = check.values[best] ?? (text: "", unit: "")
        let isBetter = check.winner == best

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: check.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize()
                Text(check.label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.textPrimary)
            .frame(height: 24)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(mine.text)
                    .font(.system(size: mine.unit.isEmpty ? 26 : 30, weight: .bold))
                if !mine.unit.isEmpty {
                    Text(mine.unit)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(isBetter ? best.chartColor : Color.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 38, alignment: .bottomLeading)
            .padding(.top, 2)
            // Under a grayed value: the best layout is not the better one on this check, so say which layout is and why.
            // The values can read the same (both Jammed) while the averages differ, so it goes by the gap, not the text.
            if !isBetter, check.margin > 0 {
                Text("\(check.winner.name) has \(check.strength).")
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(check.label): \(mine.text) \(mine.unit) in \(best.name). \(caption). \(isBetter ? "Better" : "Worse").")
        .help(isBetter ? "\(best.name) is better here" : "\(best.other.name) is better here")
    }
}


import SwiftUI

struct BestLayoutSummaryView: View {
    let summary: BestLayoutSummary
    var onInsights: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                TrophyTile(layout: summary.best)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best layout")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                    Text(summary.best.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(summary.sentence)
                        .font(.system(size: 14))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(minWidth: 180, idealWidth: 250, maxWidth: 270, alignment: .leading)
            }
            .padding(.trailing, 20)
            .frame(maxHeight: .infinity)

            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
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
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let tint = layout.chartColor
        Image(systemName: "trophy.fill")
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 74, height: 74)
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
            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 2)
        }
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(check.label): \(mine.text) \(mine.unit) in \(best.name). \(caption). \(isBetter ? "Better" : "Worse").")
        .help(isBetter ? "\(best.name) is better here" : "\(best.other.name) is better here")
    }
}

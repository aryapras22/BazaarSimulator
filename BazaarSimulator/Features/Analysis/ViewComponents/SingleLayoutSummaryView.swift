import SwiftUI

/// The bar under a project's only layout: its three headline numbers, with the Insights button for the full results.
struct SingleLayoutSummaryView: View {
    let summary: SingleLayoutSummary
    var onInsights: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 22) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 74, height: 74)
                    .background(summary.layout.tileFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Result")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                    Text(summary.layout.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.textPrimary)
                    Button("Insights", action: onInsights)
                        .buttonStyle(ControlButtonStyle())
                        .help("See how this layout does on each result, and how it changes during the day")
                        .padding(.top, 6)
                }
                .frame(width: 300, alignment: .leading)
            }
            .padding(.trailing, 26)
            .frame(maxHeight: .infinity)

            ForEach(summary.stats) { stat in
                Rectangle()
                    .fill(Color.divider)
                    .frame(width: 1)
                    .padding(.vertical, 6)
                StatColumn(stat: stat, tint: summary.layout.chartColor)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .frame(height: DashboardMetrics.singleSummaryHeight)
        .cardSurface()
    }
}

private struct StatColumn: View {
    let stat: SingleLayoutSummary.Stat
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: stat.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize()
                Text(stat.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.textPrimary)
            .frame(height: 24)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(stat.text)
                    .font(.system(size: stat.unit.isEmpty ? 26 : 30, weight: .bold))
                if !stat.unit.isEmpty {
                    Text(stat.unit)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 38, alignment: .bottomLeading)
            .padding(.top, 2)
        }
        .padding(.leading, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(stat.text) \(stat.unit). \(stat.caption).")
    }
}

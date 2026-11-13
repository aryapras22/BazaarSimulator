import SwiftUI

/// Which layout is better, why, and three numbers for it. The Insights button opens the full comparison.
struct BestLayoutBar: View {
    let summary: BestLayoutSummary
    var onShowInsights: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(summary.stats) { stat in
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(width: 1)
                    .padding(.vertical, 6)
                StatColumn(stat: stat)
                    .frame(width: 190, alignment: .leading)
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    private var leading: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(hex: 0x0066CC), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Best Layout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                Text(summary.best.name)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                Text(summary.reason)
                    .font(.system(size: 12))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                Button(action: onShowInsights) {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                        .labelStyle(InsightsLabelStyle())
                }
                .buttonStyle(ControlButtonStyle(horizontalPadding: 14))
                .padding(.top, 6)
                .help("See how the two layouts compare, check by check")
            }
        }
    }
}

private struct StatColumn: View {
    let stat: BestLayoutSummary.Stat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(stat.title, systemImage: stat.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.textPrimary)
            value
            Text(stat.other)
                .font(.system(size: 11))
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    /// "1 spot" shows the number large and the unit small. A word such as "Crowded" shows large.
    @ViewBuilder
    private var value: some View {
        let parts = stat.value.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2, parts[0].first?.isNumber == true {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(parts[0])
                    .font(.system(size: 30, weight: .semibold))
                Text(parts[1])
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color(hex: 0x0A84FF))
        } else {
            Text(stat.value)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A84FF))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct InsightsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 12, weight: .semibold))
            configuration.title
        }
    }
}

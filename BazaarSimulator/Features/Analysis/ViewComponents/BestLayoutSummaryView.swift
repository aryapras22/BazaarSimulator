
import SwiftUI

struct BestLayoutSummaryView: View {
    let summary: ProjectBestSummary
    var onInsights: () -> Void = {}

    /// The best layout's color: its card's, or a neutral one when it is not on a card.
    private var tint: Color {
        summary.place?.chartColor ?? Color.cardButtonFill
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 24) {
                TrophyTile(tint: tint)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best layout")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                    // In the layout's own color when it is on a card, the same as its tile and chart line.
                    Text(summary.name)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(summary.place == nil ? Color.textPrimary : tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Based on the average across the whole event.")
                        .font(.system(size: 13))
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("See full insights", action: onInsights)
                        .buttonStyle(ControlButtonStyle())
                        .help("Compare the layouts on stuck spots, crowd level and time stuck")
                        .padding(.top, 4)
                }
                .frame(width: 250, alignment: .leading)
            }
            .padding(.trailing, 28)
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
                            // As tall as the columns' content, not shorter by a margin at each end.
                            Rectangle()
                                .fill(Color.divider)
                                .frame(width: 1)
                        }
                        CheckColumn(check: check, tint: tint)
                    }
                }
                // Only as tall as its tallest column, so the dividers match the content and the row can be centered.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .frame(height: DashboardMetrics.summaryHeight)
        .cardSurface()
    }
}

private struct TrophyTile: View {
    let tint: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        Image(systemName: "trophy.fill")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 100, height: 100)
            .background(tint, in: shape)
            .accessibilityHidden(true)
    }
}

private struct CheckColumn: View {
    let check: ProjectBestSummary.Check
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: check.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .fixedSize()
                Text(check.label)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.textPrimary)
            .frame(height: 24)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(check.value.text)
                    .font(.system(size: check.value.unit.isEmpty ? 30 : 36, weight: .bold))
                if !check.value.unit.isEmpty {
                    Text(check.value.unit)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(check.isBest ? tint : Color.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(height: 44, alignment: .bottomLeading)
            .padding(.top, 2)
            // Under a grayed value: another layout does better on this check, so say which one and why.
            if let note = check.note {
                Text(note)
                    .font(.system(size: 13))
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(check.label): \(check.value.text) \(check.value.unit). \(check.note ?? "Best")")
    }
}

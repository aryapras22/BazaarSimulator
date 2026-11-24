import Charts
import SwiftUI

/// How the result changes during the day: a line for each layout, with the peak and the lowest of each below.
struct AnalysisChartCard: View {
    let content: AnalysisContent

    @Environment(\.layoutNames) private var names
    @State private var chartHeight: CGFloat = 300

    private var yAxisStride: Double {
        chartHeight < 170 ? content.yAxisStride * 2 : content.yAxisStride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                .padding(.horizontal, 32)
                .padding(.top, 24)

            chart
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chartHeight = $0 }
                .padding(.horizontal, 32)
                .padding(.top, 20)

            Divider()
                .overlay(Color.chartGrid)
                .padding(.horizontal, 32)
                .padding(.top, 14)

            legend
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 22)
        }
        .cardSurface(cornerRadius: Radius.panel)
    }

    // MARK: Pieces

    private var heading: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(content.chartTitle)
                    .fontWeight(.semibold)
                Text("· \(content.betterNote)")
                    .foregroundStyle(.textPrimary)
            }
            .font(.system(size: 13))
            .foregroundStyle(.textPrimary)

            if !content.comparison.isEmpty {
                Text(content.comparison)
                    .font(.system(size: 14))
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(content.series.sorted { $0.layout.rawValue < $1.layout.rawValue }) { series in
                if let peak = extremes(of: series).peak, let lowest = extremes(of: series).lowest {
                    // One row when it fits. When the card is narrow, the two numbers go on a line of their own under
                    // the name, so a value such as "Crowded (1.3/m²)" never breaks across two lines.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            name(of: series)
                                .frame(width: 112, alignment: .leading)
                            stat("Peak", at: peak)
                                .frame(minWidth: 250, alignment: .leading)
                            stat("Lowest", at: lowest)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            name(of: series)
                            HStack(spacing: 24) {
                                stat("Peak", at: peak)
                                stat("Lowest", at: lowest)
                            }
                            .padding(.leading, 20)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.textPrimary)
                }
            }
        }
    }

    private func name(of series: AnalysisContent.Series) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 9))
                .foregroundStyle(series.layout.chartColor)
            Text(names.name(series.layout))
                .fontWeight(.semibold)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private func stat(_ title: String, at point: AnalysisContent.Series.Point) -> some View {
        let time = TimeRange.format(Int((point.hour * 60).rounded()))
        return HStack(spacing: 5) {
            Text(title).foregroundStyle(.textPrimary.opacity(0.8))
            Text(content.valueText(point.value)).fontWeight(.semibold)
            Text("at \(time)").foregroundStyle(.textPrimary.opacity(0.8))
        }
        .lineLimit(1)
        .fixedSize()
    }

    private var chart: some View {
        Chart {
            ForEach(content.series) { series in
                ForEach(series.points) { point in
                    AreaMark(
                        x: .value("Time", point.hour),
                        y: .value("Value", content.plotValue(point.value)),
                        series: .value("Area", series.layout.name),
                        stacking: .unstacked
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [series.layout.chartColor.opacity(0.28), series.layout.chartColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Time", point.hour),
                        y: .value("Value", content.plotValue(point.value)),
                        series: .value("Layout", series.layout.name)
                    )
                    .foregroundStyle(series.layout.chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                ForEach(series.points) { point in
                    PointMark(
                        x: .value("Time", point.hour),
                        y: .value("Value", content.plotValue(point.value))
                    )
                    .foregroundStyle(series.layout.chartColor)
                    .symbol(.diamond)
                    .symbolSize(isExtreme(point, in: series) ? 80 : 24)
                }
            }
        }
        .chartXScale(domain: firstHour...lastHour)
        .chartYScale(domain: -yTop * 0.08...yTop * 1.08)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                // A small tick at every sampled hour, so the points can be read against the time.
                AxisTick(length: 4, stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.textPrimary.opacity(0.35))
                AxisValueLabel(
                    anchor: labelAnchor(for: value.as(Double.self)),
                    collisionResolution: .disabled,
                    verticalSpacing: 12
                ) {
                    // Only the morning, the busiest time and the evening are written out, as the points in between are
                    // too close for their words to fit. Without names for the hours, every hour is.
                    if let hour = value.as(Double.self), content.hourLabels.isEmpty || content.hourLabels[hour] != nil {
                        // The word on one line and the time under it, so neighbouring labels never meet.
                        let parts = Self.label(for: hour, in: content).components(separatedBy: " (")
                        VStack(spacing: 2) {
                            Text(parts[0])
                                .fontWeight(hour == content.peakHour ? .semibold : .regular)
                            if parts.count > 1 { Text("(" + parts[1]) }
                        }
                        .multilineTextAlignment(.center)
                        .fixedSize()
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.textPrimary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.chartGrid)
                AxisValueLabel(horizontalSpacing: 10) {
                    if let number = value.as(Double.self) {
                        Text(content.axisLabel?(number) ?? Self.number(number))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.textPrimary.opacity(0.9))
            }
        }
        .accessibilityLabel(content.chartTitle)
    }

    // MARK: Axes

    private var yAxisValues: [Double] {
        if let ticks = content.axisTicks { return ticks }
        return chartHeight < 150 ? [0, yTop] : Array(stride(from: 0, through: yTop, by: yAxisStride))
    }

    private var yTop: Double {
        max(content.yAxisMaximum, content.series.flatMap { $0.points.map { content.plotValue($0.value) } }.max() ?? 0)
    }

    private func extremes(of series: AnalysisContent.Series)
        -> (peak: AnalysisContent.Series.Point?, lowest: AnalysisContent.Series.Point?) {
        (series.points.max { $0.value < $1.value }, series.points.min { $0.value < $1.value })
    }

    private func isExtreme(_ point: AnalysisContent.Series.Point, in series: AnalysisContent.Series) -> Bool {
        let found = extremes(of: series)
        return point.hour == found.peak?.hour || point.hour == found.lowest?.hour
    }

    private var hours: [Double] {
        content.series.flatMap { $0.points.map(\.hour) }
    }

    private var firstHour: Double { hours.min() ?? 0 }

    /// Never equal to `firstHour`, so the chart always has a width.
    private var lastHour: Double { max(hours.max() ?? 0, firstHour + 1) }

    /// The hours with words under them, or every 2 hours when the content names none.
    private var xAxisValues: [Double] {
        content.hourLabels.isEmpty
            ? Array(stride(from: firstHour, through: lastHour, by: 2))
            : Array(Set(hours)).sorted()
    }

    private static func label(for hour: Double, in content: AnalysisContent) -> String {
        content.hourLabels[hour] ?? TimeRange.format(Int((hour * 60).rounded()))
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func labelAnchor(for hour: Double?) -> UnitPoint {
        guard let hour else { return .top }
        if hour == firstHour { return .topLeading }
        if hour == lastHour { return .topTrailing }
        return .top
    }
}

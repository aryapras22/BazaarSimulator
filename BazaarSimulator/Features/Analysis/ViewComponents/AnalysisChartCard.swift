import Charts
import SwiftUI

struct AnalysisChartCard: View {
    let content: AnalysisContent

    @State private var chartHeight: CGFloat = 300

    private var yAxisStride: Double {
        chartHeight < 170 ? content.yAxisStride * 2 : content.yAxisStride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                CardHeading(title: content.chartTitle, measure: content.measure)
                Spacer(minLength: 16)
                HStack(spacing: 12) {
                    ForEach(LayoutID.allCases) { layout in
                        HStack(spacing: 5) {
                            Circle().fill(layout.chartColor).frame(width: 7, height: 7)
                            Text(layout.name)
                        }
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .fixedSize()
            }
            .padding(.horizontal, CardInset.horizontal)
            .padding(.top, CardInset.top)

            chart
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chartHeight = $0 }
                .padding(.horizontal, CardInset.horizontal)
                .padding(.top, 18)
                .padding(.bottom, CardInset.bottom + 8)
        }
        .cardSurface(cornerRadius: Radius.panel)
    }

    private var chart: some View {
        Chart {
            ForEach(content.series) { series in
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Time", point.hour),
                        y: .value("Value", point.value),
                        series: .value("Layout", series.layout.name)
                    )
                    .foregroundStyle(series.layout.chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                ForEach(extremes(of: series)) { point in
                    PointMark(
                        x: .value("Time", point.hour),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(series.layout.chartColor)
                    .symbol(.diamond)
                    .symbolSize(81)
                }
            }
        }
        .chartXScale(domain: firstHour...lastHour)
        .chartYScale(domain: -yTop * 0.08...yTop * 1.08)
        .chartXAxis {
            AxisMarks(values: xAxisValues) { value in
                AxisValueLabel(
                    anchor: labelAnchor(for: value.as(Double.self)),
                    collisionResolution: .disabled,
                    verticalSpacing: 12
                ) {
                    if let hour = value.as(Double.self) {
                        Text(Self.timeLabel(hour))
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.textPrimary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.chartGrid)
                AxisValueLabel(horizontalSpacing: 14)
                    .font(.system(size: 12))
                    .foregroundStyle(.textPrimary.opacity(0.9))
            }
        }
        .accessibilityLabel(content.chartTitle)
    }

    private var yAxisValues: [Double] {
        chartHeight < 150 ? [0, yTop] : Array(stride(from: 0, through: yTop, by: yAxisStride))
    }

    private var yTop: Double {
        max(content.yAxisMaximum, content.series.flatMap { $0.points.map(\.value) }.max() ?? 0)
    }

    private func extremes(of series: AnalysisContent.Series) -> [AnalysisContent.Series.Point] {
        guard let peak = series.points.max(by: { $0.value < $1.value }),
              let lowest = series.points.min(by: { $0.value < $1.value }) else { return [] }
        return peak.hour == lowest.hour ? [peak] : [lowest, peak]
    }

    /// The sample hours of the day: the first and last hour of the series.
    private var hours: [Double] {
        content.series.flatMap { $0.points.map(\.hour) }
    }

    private var firstHour: Double { hours.min() ?? 0 }

    /// Never equal to `firstHour`, so the chart always has a width.
    private var lastHour: Double { max(hours.max() ?? 0, firstHour + 1) }

    /// Labels every 2 hours from the first hour.
    private var xAxisValues: [Double] {
        Array(stride(from: firstHour, through: lastHour, by: 2))
    }

    /// "HH:00" for a whole hour, "HH:mm" otherwise.
    private static func timeLabel(_ hour: Double) -> String {
        TimeRange.format(Int((hour * 60).rounded()))
    }

    private func labelAnchor(for hour: Double?) -> UnitPoint {
        guard let hour else { return .top }
        if hour == firstHour { return .topLeading }
        if hour == lastHour { return .topTrailing }
        return .top
    }
}

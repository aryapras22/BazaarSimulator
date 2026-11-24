import Foundation

struct AnalysisContent: Sendable {
    struct Tile: Identifiable, Sendable {
        let layout: LayoutID
        let value: String
        let caption: String
        let bullets: [String]
        var unit = ""
        var id: LayoutID { layout }
    }

    struct Metric: Sendable {
        let value: String
        var isHighlighted = false
    }

    struct Row: Identifiable, Sendable {
        let layout: LayoutID
        let minimum: Metric
        let average: Metric
        let maximum: Metric
        let meaning: String
        var id: LayoutID { layout }
    }

    struct Series: Identifiable, Sendable {
        struct Point: Identifiable, Sendable {
            let hour: Double
            let value: Double
            var id: Double { hour }
        }

        let layout: LayoutID
        let points: [Point]
        var id: LayoutID { layout }
    }

    struct Fact: Identifiable, Sendable {
        let symbol: String
        let text: String
        var id: String { text }
    }

    let recommended: LayoutID
    let headline: String
    let symbol: String
    let tiles: [Tile]
    let rows: [Row]
    let tableTitle: String
    let chartTitle: String
    let yAxisMaximum: Double
    let yAxisStride: Double
    let series: [Series]
    let infoQuestion: String
    let explanation: String
    var unit = ""
    var singularUnit: String?
    var measure = ""
    var columns = ["Lowest", "Average", "Peak"]
    var facts: [Fact] = []
    /// Overrides "Best for <tab>" on the recommendation card, for a project with one layout.
    var cardTitle: String?
    /// "lower is better", shown after the chart title.
    var betterNote = "lower is better"
    /// One sentence about who does better through the day, under the chart title. Empty with one layout.
    var comparison = ""
    /// The hour of the busiest time, and the words under each hour of the chart.
    var peakHour: Double?
    var hourLabels: [Double: String] = [:]
    /// Where the chart's value axis is labelled, when it is not every `yAxisStride`, and how a value reads.
    var axisTicks: [Double]?
    var axisLabel: (@Sendable (Double) -> String)?
    /// Where a value sits on the chart's value axis, when the axis is not a straight scale. The crowd level axis gives
    /// every level the same room. `yAxisMaximum` and `axisTicks` are in these places.
    var plotValue: @Sendable (Double) -> Double = { $0 }
    var valueText: @Sendable (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0...1))) }

    func unit(for value: Double) -> String {
        value == 1 ? singularUnit ?? unit : unit
    }
}

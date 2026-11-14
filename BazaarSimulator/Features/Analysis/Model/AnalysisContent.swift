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

    func unit(for value: Double) -> String {
        value == 1 ? singularUnit ?? unit : unit
    }
}

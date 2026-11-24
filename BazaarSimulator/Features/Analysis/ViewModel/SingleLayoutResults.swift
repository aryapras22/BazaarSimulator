import Foundation

/// What the Analysis page shows for a project with one layout: there is nothing to compare, so each result is that
/// layout's own. The numbers come from the same outcome the comparison uses.
enum SingleLayoutContent {
    /// One tab's content for a single layout. The tiles, table row, and chart line are that layout's, and the
    /// wording describes it on its own instead of against another layout.
    static func content(
        for tab: AnalysisTab, outcome: LayoutOutcome, peakHourText: String, windowMinutes: Double
    ) -> AnalysisContent {
        // The engine builds every figure per layout, so it is asked with the layout twice and only its own row,
        // tile and line are kept. Nothing from the comparison between the two survives.
        let twin = LayoutOutcome(
            layout: .two, name: LayoutID.two.name, windowMinutes: outcome.windowMinutes,
            spots: outcome.spots, dayPoints: outcome.dayPoints
        )
        let built = CompareRulesEngine(
            outcomes: [.one: outcome, .two: twin], peakHourText: peakHourText, windowMinutes: windowMinutes
        ).content(for: tab)

        var single = AnalysisContent(
            recommended: .one,
            headline: headline(for: tab, outcome: outcome, peakHourText: peakHourText),
            symbol: built.symbol,
            tiles: built.tiles.filter { $0.layout == .one },
            rows: built.rows.filter { $0.layout == .one },
            tableTitle: built.tableTitle.replacingOccurrences(of: " by Layout", with: ""),
            chartTitle: built.chartTitle,
            yAxisMaximum: built.yAxisMaximum,
            yAxisStride: built.yAxisStride,
            series: built.series.filter { $0.layout == .one },
            infoQuestion: built.infoQuestion,
            explanation: built.explanation,
            unit: built.unit,
            singularUnit: built.singularUnit,
            measure: built.measure,
            columns: built.columns,
            facts: built.facts.filter { $0.text != "Fewer is better" && $0.text != "Lower is better" },
            cardTitle: tab.title
        )
        single.betterNote = built.betterNote
        single.peakHour = built.peakHour
        single.hourLabels = built.hourLabels
        single.axisTicks = built.axisTicks
        single.axisLabel = built.axisLabel
        single.plotValue = built.plotValue
        single.valueText = built.valueText
        return single
    }

    static func headline(for tab: AnalysisTab, outcome: LayoutOutcome, peakHourText: String) -> String {
        switch tab {
        case .congestionPoints:
            let spots = outcome.C
            return spots == 0
                ? "Nobody gets stuck, even at the busiest time (\(peakHourText))."
                : "At the busiest time (\(peakHourText)), people get stuck in \(spots) \(spots == 1 ? "spot" : "spots at once")."
        case .congestionDuration:
            return outcome.M < 0.25
                ? "People keep moving, even at the busiest time (\(peakHourText))."
                : "At the busiest time (\(peakHourText)), people stay stuck for about \(minutes(outcome.M)) min."
        case .crowdDensity:
            let space = outcome.space.formatted(.number.precision(.fractionLength(1)))
            return "At its busiest spot each person has about \(space) m² of aisle: \(outcome.worstSpot.grade.crowdLevel.lowercased())."
        case .flowRate:
            let low = outcome.flowMin.formatted(.number.precision(.fractionLength(0)))
            let high = outcome.flowMax.formatted(.number.precision(.fractionLength(0)))
            return low == high
                ? "About \(low) people walk past every minute."
                : "Between \(low) and \(high) people walk past every minute through the day."
        }
    }

    /// Whole minutes show without a decimal, and anything else to the nearest half minute.
    static func minutes(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        return rounded == rounded.rounded()
            ? String(Int(rounded))
            : rounded.formatted(.number.precision(.fractionLength(1)))
    }
}

/// The three headline numbers for the one layout, under its plan.
struct SingleLayoutSummary {
    struct Stat: Identifiable {
        let title: String
        let symbol: String
        let text: String
        let unit: String
        let caption: String
        var id: String { title }
    }

    let layout: LayoutID
    let stats: [Stat]

    init(layout: LayoutID, outcome: LayoutOutcome) {
        self.layout = layout
        let stuck = outcome.C
        stats = [
            Stat(
                title: "Stuck Spots", symbol: "exclamationmark.triangle.fill",
                text: "\(stuck)", unit: stuck == 1 ? "spot" : "spots", caption: "Stuck at once"
            ),
            Stat(
                title: "Time Stuck", symbol: "clock.fill",
                text: SingleLayoutContent.minutes(outcome.M), unit: "min", caption: "Total Duration"
            ),
            Stat(
                title: "Crowd Level", symbol: "person.3.fill",
                text: outcome.worstSpot.grade.crowdLevel, unit: "", caption: "Overall Condition"
            )
        ]
    }
}

import Foundation

/// The Best Layout card: the best of all the project's layouts, which may not be on a card of the page, and for each
/// of the three checks how it does on average and which layout does better when it is not the best on that check.
struct ProjectBestSummary {
    struct Check: Identifiable {
        let tab: AnalysisTab
        let label: String
        let symbol: String
        /// The best layout's average, with the unit apart so the number can be set large.
        let value: (text: String, unit: String)
        /// The best layout does best of all the layouts on this check.
        let isBest: Bool
        /// When it does not, which layout does, such as "Layout 1 has fewer stuck spots."
        let note: String?

        var id: AnalysisTab { tab }
    }

    /// The best layout's name, as the project numbers it.
    let name: String
    /// The card the best layout is on, if it is on one. It gives the layout its color.
    let place: LayoutID?
    let checks: [Check]

    init(best: ProjectOutcome, all: [ProjectOutcome], place: LayoutID?) {
        name = best.outcome.name
        self.place = place
        let tabs: [AnalysisTab] = [.congestionPoints, .crowdDensity, .congestionDuration]
        checks = tabs.map { tab in
            let averages = all.map { BestLayoutSummary.average(for: tab, outcome: $0.outcome) }
            let mine = BestLayoutSummary.average(for: tab, outcome: best.outcome)
            // Lower is better on every check, and the layout with the lowest average does best of all.
            let lowest = averages.min() ?? mine
            let isBest = mine <= lowest + 1e-9
            let winner = zip(all, averages).first { _, average in average <= lowest + 1e-9 }?.0
            return Check(
                tab: tab,
                label: tab.title,
                symbol: BestLayoutSummary.symbol(for: tab),
                value: BestLayoutSummary.value(for: tab, average: mine),
                isBest: isBest,
                note: isBest ? nil : winner.map { "\($0.outcome.name) has \(BestLayoutSummary.strength(for: tab))." }
            )
        }
    }
}

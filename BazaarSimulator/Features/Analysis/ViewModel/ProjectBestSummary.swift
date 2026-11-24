import Foundation

/// The Best Layout card: the best of all the project's layouts, which may not be on a card of the page, and for each
/// of the three checks how it does on average against the layout on the other card, the one being looked at.
struct ProjectBestSummary {
    struct Check: Identifiable {
        let tab: AnalysisTab
        let label: String
        let symbol: String
        /// The best layout's average, with the unit apart so the number can be set large.
        let value: (text: String, unit: String)
        /// The best layout does at least as well as the other layout on this check.
        let isBest: Bool
        /// When it does not, which layout does, such as "Layout 6 has fewer stuck spots."
        let note: String?

        var id: AnalysisTab { tab }
    }

    /// The best layout's name, as the project numbers it.
    let name: String
    /// The card the best layout is on, if it is on one. It gives the layout its color.
    let place: LayoutID?
    let checks: [Check]

    init(best: ProjectOutcome, against other: ProjectOutcome?, place: LayoutID?) {
        name = best.outcome.name
        self.place = place
        let tabs: [AnalysisTab] = [.congestionPoints, .crowdDensity, .congestionDuration]
        checks = tabs.map { tab in
            let mine = BestLayoutSummary.average(for: tab, outcome: best.outcome)
            // Lower is better on every check.
            let theirs = other.map { BestLayoutSummary.average(for: tab, outcome: $0.outcome) }
            let isBest = theirs.map { mine <= $0 + 1e-9 } ?? true
            return Check(
                tab: tab,
                label: tab.title,
                symbol: BestLayoutSummary.symbol(for: tab),
                value: BestLayoutSummary.value(for: tab, average: mine),
                isBest: isBest,
                note: isBest ? nil : other.map { "\($0.outcome.name) has \(BestLayoutSummary.strength(for: tab))." }
            )
        }
    }
}

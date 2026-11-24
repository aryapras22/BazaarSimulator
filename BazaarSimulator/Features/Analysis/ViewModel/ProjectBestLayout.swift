import Foundation

/// One layout of the project with how it did, whether or not it is on a card of the page.
struct ProjectOutcome: Sendable {
    let layoutID: Layout.ID
    /// Its name is the project's number for the layout, such as "Layout 3".
    let outcome: LayoutOutcome
}

/// Which layout is the best of all the layouts of a project, not only of the two on the page.
///
/// Every pair of layouts is compared the way the Best Layout summary compares two, with the same checks and the same
/// scoring. The layout that wins the most pairs is the best. Layouts that win as many pairs are told apart by how
/// much they win by, the points the summary gives each pair.
enum ProjectBestLayout {
    static func best(of outcomes: [ProjectOutcome], peakHourText: String, windowMinutes: Double) -> Layout.ID? {
        guard outcomes.count > 1 else { return outcomes.first?.layoutID }
        var wins = Array(repeating: 0, count: outcomes.count)
        var points = Array(repeating: 0.0, count: outcomes.count)
        for first in outcomes.indices {
            for second in outcomes.indices where second > first {
                let pair: [LayoutID: LayoutOutcome] = [
                    .one: outcomes[first].outcome.relabeled(as: .one),
                    .two: outcomes[second].outcome.relabeled(as: .two)
                ]
                let engine = CompareRulesEngine(
                    outcomes: pair, peakHourText: peakHourText, windowMinutes: windowMinutes
                )
                let summary = BestLayoutSummary(engine: engine, outcomes: pair)
                let gap = (summary.scores[.one] ?? 0) - (summary.scores[.two] ?? 0)
                points[first] += gap
                points[second] -= gap
                wins[summary.best == .one ? first : second] += 1
            }
        }
        let ranked = outcomes.indices.max { lhs, rhs in
            wins[lhs] != wins[rhs] ? wins[lhs] < wins[rhs] : points[lhs] < points[rhs]
        }
        return ranked.map { outcomes[$0].layoutID }
    }
}

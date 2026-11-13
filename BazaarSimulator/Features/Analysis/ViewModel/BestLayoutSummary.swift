import Foundation

/// The one-line answer on the compare page: which layout is better overall, why, and three headline numbers for it.
struct BestLayoutSummary: Sendable {
    struct Stat: Identifiable, Sendable {
        let title: String
        let symbol: String
        /// The best layout's value, such as "1 spot" or "Crowded".
        let value: String
        /// How the other layout did, such as "Layout 1: 3 spots".
        let other: String
        var id: String { title }
    }

    let best: LayoutID
    let reason: String
    let stats: [Stat]

    /// The layout that wins most of the three measures, and on a tie the one that wins Congestion Points.
    init(engine: CompareRulesEngine, outcomes: [LayoutID: LayoutOutcome]) {
        let points = engine.content(for: .congestionPoints)
        let duration = engine.content(for: .congestionDuration)
        let density = engine.content(for: .crowdDensity)
        let winners = [points.recommended, duration.recommended, density.recommended]
        let best = LayoutID.allCases.max { first, second in
            let firstWins = winners.filter { $0 == first }.count
            let secondWins = winners.filter { $0 == second }.count
            return firstWins == secondWins ? first == points.recommended : firstWins < secondWins
        } ?? points.recommended
        let other = best.other

        var reasons: [String] = []
        if points.recommended == best { reasons.append("fewer stuck spots") }
        if duration.recommended == best { reasons.append("less time stuck") }
        if density.recommended == best { reasons.append("calmer crowds") }

        self.best = best
        self.reason = Self.sentence(reasons)
        self.stats = [
            Self.stat("Crowded Spots", "exclamationmark.triangle.fill", points, best, other),
            Self.stat("Time Stuck", "clock.fill", duration, best, other),
            Stat(
                title: "Crowd Level",
                symbol: "person.3.fill",
                value: outcomes[best]?.worstSpot.grade.title ?? "",
                other: "\(other.name): \(outcomes[other]?.worstSpot.grade.title ?? "")"
            )
        ]
    }

    private static func stat(
        _ title: String, _ symbol: String, _ content: AnalysisContent, _ best: LayoutID, _ other: LayoutID
    ) -> Stat {
        let value = content.tiles.first { $0.layout == best }?.value ?? ""
        let otherValue = content.tiles.first { $0.layout == other }?.value ?? ""
        return Stat(title: title, symbol: symbol, value: value, other: "\(other.name): \(otherValue)")
    }

    /// "Fewer stuck spots, less time stuck and calmer crowds."
    static func sentence(_ reasons: [String]) -> String {
        guard let last = reasons.last else { return "Both layouts do about the same." }
        let joined = reasons.count == 1
            ? last
            : reasons.dropLast().joined(separator: ", ") + " and " + last
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }
}

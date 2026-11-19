import Foundation

/// The one-line answer on the compare page: which layout is better overall, why, what it costs, and the three checks
/// behind it. Every value is read from the same results the Insights tabs show.
struct BestLayoutSummary {
    struct Check: Identifiable {
        let tab: AnalysisTab
        let label: String
        let symbol: String
        let winner: LayoutID
        /// Each layout's value, with the unit apart so the number can be set large.
        let values: [LayoutID: (text: String, unit: String)]
        let strength: String
        let tradeOff: String
        /// How far apart the two layouts are on this check, from 0 (the same) to 1 (as far apart as it can be).
        let margin: Double

        var id: AnalysisTab { tab }

        /// The gap is so wide that this check counts for more than usual.
        var isHuge: Bool { !isTie && margin >= BestLayoutSummary.hugeMargin }

        /// Both layouts show the same value, so the check has no winner worth naming.
        var isTie: Bool {
            guard let one = values[.one], let two = values[.two] else { return false }
            return one.text == two.text && one.unit == two.unit
        }
    }

    /// How much each check counts for. Crowd level and time stuck count a little more than stuck spots, because
    /// stuck spots only says how many places jam, not how bad the worst one gets or for how long.
    static let weights: [AnalysisTab: Double] = [
        .congestionPoints: 1.0,
        .crowdDensity: 1.25,
        .congestionDuration: 1.25,
    ]
    /// From this gap on, a check is a huge difference: half of the whole scale between the two layouts.
    static let hugeMargin = 0.5
    /// A huge difference counts this many times over.
    static let hugeBoost = 2.0
    /// Scores closer than this are a tie, which the older rule then settles.
    static let tieBand = 0.05

    let checks: [Check]
    let best: LayoutID
    /// Each layout's score. The higher one is best.
    let scores: [LayoutID: Double]

    /// Each check gives its winner points: the check's weight times how far apart the layouts are, counted
    /// double when the gap is huge. The layout with more points is best. When the points are level, it is the
    /// layout that wins most of the checks, and then the one that wins the first check that is not a tie.
    init(engine: CompareRulesEngine, outcomes: [LayoutID: LayoutOutcome]) {
        let tabs: [AnalysisTab] = [.congestionPoints, .crowdDensity, .congestionDuration]
        let built: [Check] = tabs.map { tab in
            let content = engine.content(for: tab)
            return Check(
                tab: tab,
                label: tab.title,
                symbol: Self.symbol(for: tab),
                winner: content.recommended,
                values: Dictionary(uniqueKeysWithValues: LayoutID.allCases.map { layout in
                    (layout, Self.value(for: tab, layout: layout, content: content, outcomes: outcomes))
                }),
                strength: Self.strength(for: tab),
                tradeOff: Self.tradeOff(for: tab),
                margin: Self.margin(for: tab, outcomes: outcomes, windowMinutes: engine.windowMinutes)
            )
        }
        checks = built

        var points: [LayoutID: Double] = [.one: 0, .two: 0]
        for check in built where !check.isTie {
            let boost = check.isHuge ? Self.hugeBoost : 1
            points[check.winner, default: 0] += (Self.weights[check.tab] ?? 1) * check.margin * boost
        }
        scores = points

        let gap = (points[.one] ?? 0) - (points[.two] ?? 0)
        if abs(gap) >= Self.tieBand {
            best = gap > 0 ? .one : .two
        } else {
            let decided = built.filter { !$0.isTie }
            let winsOne = decided.filter { $0.winner == .one }.count
            let winsTwo = decided.count - winsOne
            best = winsOne == winsTwo ? (decided.first ?? built[0]).winner : (winsTwo > winsOne ? .two : .one)
        }
    }

    /// How far apart the layouts are on one check, from 0 to 1.
    private static func margin(for tab: AnalysisTab, outcomes: [LayoutID: LayoutOutcome], windowMinutes: Double) -> Double {
        guard let one = outcomes[.one], let two = outcomes[.two] else { return 0 }
        let value: Double
        switch tab {
        case .congestionPoints:
            // One spot against none is as far apart as it gets. Three against four is a quarter.
            value = Double(abs(one.C - two.C)) / Double(max(one.C, two.C, 1))
        case .congestionDuration:
            // Out of the busiest window, so 2 minutes against 8 in a 10 minute window is 0.6.
            value = abs(one.M - two.M) / max(windowMinutes, 1)
        default:
            // Out of the larger density, kept at least as large as grade B's limit so a calm 0.05 against 0.10
            // does not read as a huge difference.
            value = abs(one.D - two.D) / max(one.D, two.D, 0.27)
        }
        return min(max(value, 0), 1)
    }

    /// "Fewer stuck spots, less time stuck and calmer crowds. The trade-off: ..."
    var sentence: String {
        let decided = checks.filter { !$0.isTie }
        guard !decided.isEmpty else { return "Both layouts do the same on all three checks." }
        let strengths = decided.filter { $0.winner == best }.map(\.strength)
        let tradeOffs = decided.filter { $0.winner != best }.map(\.tradeOff)
        var text = Self.capitalized(Self.list(strengths)) + "."
        if !tradeOffs.isEmpty {
            text += " The trade-off: \(Self.list(tradeOffs))."
        }
        return text
    }

    /// How the other layout did, such as "Layout 1: 3 spots".
    func caption(for check: Check) -> String {
        guard let other = check.values[best.other] else { return "" }
        return "\(best.other.name): \(other.text)\(other.unit.isEmpty ? "" : " \(other.unit)")"
    }

    // MARK: Words

    private static func value(
        for tab: AnalysisTab, layout: LayoutID, content: AnalysisContent, outcomes: [LayoutID: LayoutOutcome]
    ) -> (text: String, unit: String) {
        if tab == .crowdDensity {
            return (outcomes[layout]?.worstSpot.grade.crowdLevel ?? "", "")
        }
        if let own = content.tiles.first(where: { $0.layout == layout }), !own.unit.isEmpty {
            return (own.value, own.unit)
        }
        let tile = content.tiles.first { $0.layout == layout }?.value ?? ""
        let parts = tile.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? tile, parts.count > 1 ? parts[1] : "")
    }

    private static func symbol(for tab: AnalysisTab) -> String {
        switch tab {
        case .congestionPoints: "exclamationmark.triangle"
        case .congestionDuration: "clock"
        default: "person.3"
        }
    }

    private static func strength(for tab: AnalysisTab) -> String {
        switch tab {
        case .congestionPoints: "fewer stuck spots"
        case .congestionDuration: "less time stuck"
        default: "calmer crowds"
        }
    }

    private static func tradeOff(for tab: AnalysisTab) -> String {
        switch tab {
        case .congestionPoints: "it has more stuck spots"
        case .congestionDuration: "people stay stuck longer"
        default: "it gets more crowded"
        }
    }

    static func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        return items.count > 1 ? items.dropLast().joined(separator: ", ") + " and " + last : last
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

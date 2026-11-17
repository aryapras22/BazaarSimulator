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

        var id: AnalysisTab { tab }

        /// Both layouts show the same value, so the check has no winner worth naming.
        var isTie: Bool {
            guard let one = values[.one], let two = values[.two] else { return false }
            return one.text == two.text && one.unit == two.unit
        }
    }

    let checks: [Check]
    let best: LayoutID

    /// The layout that wins most of the three checks, and on a tie the one that wins the first check that is
    /// not itself a tie.
    init(engine: CompareRulesEngine, outcomes: [LayoutID: LayoutOutcome]) {
        let tabs: [AnalysisTab] = [.congestionPoints, .congestionDuration, .crowdDensity]
        checks = tabs.map { tab in
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
                tradeOff: Self.tradeOff(for: tab)
            )
        }
        let decided = checks.filter { !$0.isTie }
        let winsOne = decided.filter { $0.winner == .one }.count
        let winsTwo = decided.count - winsOne
        best = winsOne == winsTwo ? (decided.first ?? checks[0]).winner : (winsTwo > winsOne ? .two : .one)
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
            return (outcomes[layout]?.worstSpot.grade.title ?? "", "")
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

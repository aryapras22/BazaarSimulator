import Foundation

struct CompareRulesEngine: Sendable {
    let outcomes: [LayoutID: LayoutOutcome]
    let peakHourText: String
    let windowMinutes: Double

    init(
        outcomes: [LayoutID: LayoutOutcome],
        peakHourText: String = "14:00",
        windowMinutes: Double = 10.0
    ) {
        self.outcomes = outcomes
        self.peakHourText = peakHourText
        self.windowMinutes = windowMinutes
    }

    func content(for tab: AnalysisTab) -> AnalysisContent {
        switch tab {
        case .congestionPoints:
            return buildCongestionPoints()
        case .congestionDuration:
            return buildCongestionDuration()
        case .crowdDensity:
            return buildCrowdDensity()
        case .flowRate:
            return buildFlowRate()
        }
    }

    // MARK: - 1. Congestion Points

    private func buildCongestionPoints() -> AnalysisContent {
        let win = pickWinner(
            primary: { Double($0.C) },
            tieBreak: { $0.Cavg },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)

        let headline = oWin.C == oLose.C
            ? (oWin.C == 0
                ? "Neither layout has spots where people get stuck, even at the busiest time (\(peakHourText))."
                : "Both layouts have \(oWin.C) \(spotsWord(oWin.C)) where people get stuck\(atOnce(oWin.C)) at the busiest time (\(peakHourText)).")
            : oWin.C == 0
            ? "\(oWin.name) has no spots where people get stuck, even at the busiest time (\(peakHourText)). \(oLose.name) has \(oLose.C)."
            : "\(oWin.name) has only \(oWin.C) \(spotsWord(oWin.C)) where people get stuck\(atOnce(oWin.C)) at the busiest time (\(peakHourText)). \(oLose.name) has \(oLose.C)."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let c = out.C
            let worst = out.worstSpot
            let bullets: [String]
            if c == 0 {
                bullets = ["Busiest: \(worst.name)", "Busy, but nobody gets stuck"]
            } else if c == 1 {
                bullets = ["Only at \(worst.name)", "Up to \(worst.peakVisitors) people at once"]
            } else {
                bullets = ["Worst: \(worst.name)", "Up to \(worst.peakVisitors) people at once"]
            }
            return AnalysisContent.Tile(
                layout: layout,
                value: "\(c) \(spotsWord(c))",
                caption: "\(c == 1 ? "Spot" : "Spots") where people get stuck\(atOnce(c)) at \(peakHourText)",
                bullets: bullets,
                unit: ""
            )
        }

        let rows = makeTableRows(
            valueExtractor: { Double($0.jammedSpots) },
            formatter: Self.formatCountOrAvg,
            lowerIsBetter: true,
            meaningGenerator: { out in
                out.C == 0 ? "Nobody gets stuck" : "People get stuck in \(out.C) \(self.spotsWord(out.C))\(self.atOnce(out.C)) at \(self.peakHourText)"
            }
        )

        let maxSpots = Double(max(outcomes[.one]?.spotTotal ?? 1, outcomes[.two]?.spotTotal ?? 1))

        return AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "exclamationmark.triangle.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Congestion Points by Layout",
            chartTitle: "Congestion Points Throughout the Day",
            yAxisMaximum: maxSpots,
            yAxisStride: 1,
            series: makeSeries { Double($0.jammedSpots) },
            infoQuestion: "What's Congestion Points?",
            explanation: "A spot so crowded that people get stuck.",
            unit: "spots",
            singularUnit: "spot",
            measure: "Spots where people get stuck at once",
            facts: [
                AnalysisContent.Fact(symbol: "person.3.fill", text: "Over 1 person per m² (grade E or F)"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Counts the spots stuck at the same moment"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Fewer is better"),
            ]
        )
    }

    // MARK: - 2. Congestion Duration

    private func buildCongestionDuration() -> AnalysisContent {
        let win = pickWinner(
            primary: { $0.M },
            tieBreak: { $0.Msum },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)

        let loseTime = oLose.M >= windowMinutes - 0.25
            ? "all \(Self.formatHalfMinutes(windowMinutes)) minutes"
            : "for \(Self.formatHalfMinutes(oLose.M)) of \(Self.formatHalfMinutes(windowMinutes)) minutes"

        let sameTime = Self.formatHalfMinutes(oWin.M) == Self.formatHalfMinutes(oLose.M)
        let headline = sameTime
            ? (oLose.M < 0.25
                ? "Nobody gets stuck in either layout at \(peakHourText)."
                : "At \(peakHourText), people are stuck about \(Self.formatHalfMinutes(oWin.M)) minutes in both layouts.")
            : oWin.M < 0.25
            ? "Nobody gets stuck in \(oWin.name) at \(peakHourText). In \(oLose.name), people are stuck \(loseTime)."
            : "At \(peakHourText), people are stuck \(Self.formatHalfMinutes(oLose.M - oWin.M)) minutes less in \(oWin.name) than in \(oLose.name)."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let qualifying = out.spots
                .filter { $0.stuckMin >= 0.25 }
                .sorted { $0.stuckMin > $1.stuckMin }
                .prefix(2)
                .map { "\($0.name): \(Self.formatHalfMinutes($0.stuckMin)) min" }
            let bullets = qualifying.isEmpty
                ? ["Nobody gets stuck", "People keep moving"]
                : Array(qualifying)
            return AnalysisContent.Tile(
                layout: layout,
                value: "\(Self.formatHalfMinutes(out.M)) min",
                caption: "Time people stay stuck at \(peakHourText)",
                bullets: bullets,
                unit: ""
            )
        }

        let rows = makeTableRows(
            valueExtractor: { $0.heavyMinutes },
            formatter: Self.formatTableMinutes,
            lowerIsBetter: true,
            meaningGenerator: { out in
                self.jamMeaning(out.M, window: self.windowMinutes)
            }
        )

        let maxDuration = Self.axisMax(
            LayoutID.allCases.flatMap { outcome(for: $0).dayPoints.map(\.heavyMinutes) },
            step: 2,
            minimum: 4
        )

        return AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "clock.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Congestion Duration by Layout",
            chartTitle: "Congestion Duration Throughout the Day",
            yAxisMaximum: maxDuration,
            yAxisStride: 2,
            series: makeSeries { $0.heavyMinutes },
            infoQuestion: "What's Congestion Duration?",
            explanation: "How long people stay stuck at the busiest time.",
            unit: "min",
            measure: "Minutes people stay stuck, out of \(Self.formatHalfMinutes(windowMinutes))",
            facts: [
                AnalysisContent.Fact(symbol: "person.3.fill", text: "Stuck means grade E or F"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Checked at each spot all day"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Shorter is better"),
            ]
        )
    }

    // MARK: - 3. Crowd Density

    private func buildCrowdDensity() -> AnalysisContent {
        let win = pickWinner(
            primary: { $0.D },
            tieBreak: { _ in 0 },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)

        let headline = Self.formatDecimal1(oWin.space) == Self.formatDecimal1(oLose.space)
            ? "Both layouts leave about \(Self.formatDecimal1(oWin.space)) m² for each person at their busiest spot."
            : "\(oWin.name) leaves about \(Self.formatDecimal1(oWin.space)) m² for each person at its busiest spot. \(oLose.name) leaves only \(Self.formatDecimal1(oLose.space)) m²."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            return AnalysisContent.Tile(
                layout: layout,
                value: "\(Self.formatDecimal1(out.D)) per m²",
                caption: "People per m² at the busiest spot",
                bullets: [
                    "About \(Self.formatDecimal1(out.space)) m² per person",
                    out.worstSpot.grade.shortMeaning
                ],
                unit: ""
            )
        }

        let rows = makeTableRows(
            valueExtractor: { $0.worstDensity },
            formatter: Self.formatDecimal1,
            lowerIsBetter: true,
            meaningGenerator: { $0.worstSpot.grade.plainMeaning }
        )

        let maxDensity = Self.axisMax(
            LayoutID.allCases.flatMap { outcome(for: $0).dayPoints.map(\.worstDensity) },
            step: 0.5,
            minimum: 1.0
        )

        return AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "person.3.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Crowd Density by Layout",
            chartTitle: "Crowd Density Throughout the Day",
            yAxisMaximum: maxDensity,
            yAxisStride: 0.5,
            series: makeSeries { $0.worstDensity },
            infoQuestion: "What's Crowd Density?",
            explanation: "How many people share each m² of aisle at the busiest spot.",
            unit: "per m²",
            measure: "People per m² at the busiest spot",
            facts: [
                AnalysisContent.Fact(symbol: "person.2.fill", text: "About 2 per m²: shoulders touch"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Checked at the busiest spot all day"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Lower is better"),
            ]
        )
    }

    // MARK: - 4. Flow Rate

    private func buildFlowRate() -> AnalysisContent {
        let win = pickWinner(
            primary: { $0.flowMin },
            tieBreak: { -$0.swing },
            lowerIsBetter: false
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)

        let headline: String
        if Self.formatCountOrAvg(oWin.flowMin) == Self.formatCountOrAvg(oLose.flowMin) {
            headline = "Both layouts drop to \(Self.formatCountOrAvg(oWin.flowMin)) people a minute at their slowest."
        } else if oWin.isSteady && !oLose.isSteady {
            headline = "\(oWin.name) keeps at least \(Self.formatCountOrAvg(oWin.flowMin)) people walking past every minute. \(oLose.name) sometimes drops to \(Self.formatCountOrAvg(oLose.flowMin))."
        } else {
            headline = "\(oWin.name) never drops below \(Self.formatCountOrAvg(oWin.flowMin)) people a minute. \(oLose.name) drops to \(Self.formatCountOrAvg(oLose.flowMin))."
        }

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let fMin = Self.formatCountOrAvg(out.flowMin)
            let fMax = Self.formatCountOrAvg(out.flowMax)
            let bullets = out.isSteady
                ? ["Steady all day", "Never below \(fMin) per min"]
                : ["Up and down all day", "Sometimes drops to \(fMin) per min"]
            return AnalysisContent.Tile(
                layout: layout,
                value: "\(fMin)–\(fMax) per min",
                caption: "People walking past each minute",
                bullets: bullets,
                unit: ""
            )
        }

        let rows = makeTableRows(
            valueExtractor: { $0.flowRate },
            formatter: Self.formatCountOrAvg,
            lowerIsBetter: false,
            meaningGenerator: { out in
                out.isSteady ? "People keep moving at a steady pace" : "People speed up and slow down a lot"
            }
        )

        let maxFlow = max(25.0, LayoutID.allCases.flatMap { outcome(for: $0).dayPoints.map(\.flowRate) }.max() ?? 25.0)

        return AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "figure.run",
            tiles: tiles,
            rows: rows,
            tableTitle: "Flow Rate by Layout",
            chartTitle: "Flow Rate Throughout the Day",
            yAxisMaximum: maxFlow,
            yAxisStride: 5,
            series: makeSeries { $0.flowRate },
            infoQuestion: "What's Flow Rate?",
            explanation: "How many people walk past one point each minute.",
            unit: "per min",
            measure: "People walking past each minute",
            facts: [
                AnalysisContent.Fact(symbol: "waveform.path", text: "Drops mean people are bunching up"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Counted in the main aisle all day"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Steady is better"),
            ]
        )
    }

    // MARK: - Helpers

    private func outcome(for layout: LayoutID) -> LayoutOutcome {
        outcomes[layout] ?? LayoutOutcome(
            layout: layout,
            name: layout.name,
            windowMinutes: windowMinutes,
            spots: [],
            dayPoints: []
        )
    }

    private func pickWinner(
        primary: (LayoutOutcome) -> Double,
        tieBreak: (LayoutOutcome) -> Double,
        lowerIsBetter: Bool
    ) -> LayoutID {
        let o1 = outcome(for: .one)
        let o2 = outcome(for: .two)
        let p1 = primary(o1)
        let p2 = primary(o2)

        if p1 != p2 {
            let oneWins = lowerIsBetter ? p1 < p2 : p1 > p2
            return oneWins ? .one : .two
        }

        let t1 = tieBreak(o1)
        let t2 = tieBreak(o2)
        if t1 != t2 {
            let oneWins = lowerIsBetter ? t1 < t2 : t1 > t2
            return oneWins ? .one : .two
        }

        return .one
    }

    private func makeTableRows(
        valueExtractor: (DayPoint) -> Double,
        formatter: (Double) -> String,
        lowerIsBetter: Bool,
        meaningGenerator: (LayoutOutcome) -> String
    ) -> [AnalysisContent.Row] {
        let statsByLayout = Dictionary(uniqueKeysWithValues: LayoutID.allCases.map { layout -> (LayoutID, (lowest: Double, average: Double, peak: Double)) in
            let points = outcome(for: layout).dayPoints.map(valueExtractor)
            let lowest = points.min() ?? 0
            let average = points.isEmpty ? 0 : points.reduce(0, +) / Double(points.count)
            let peak = points.max() ?? 0
            return (layout, (lowest, average, peak))
        })

        let s1 = statsByLayout[.one]!
        let s2 = statsByLayout[.two]!

        func isHighlighted(_ v1: Double, _ v2: Double) -> Bool {
            if v1 == v2 { return false }
            return lowerIsBetter ? v1 < v2 : v1 > v2
        }

        return LayoutID.allCases.map { layout in
            let mine = statsByLayout[layout]!
            let other = statsByLayout[layout.other]!
            let out = outcome(for: layout)
            return AnalysisContent.Row(
                layout: layout,
                minimum: AnalysisContent.Metric(
                    value: formatter(mine.lowest),
                    isHighlighted: isHighlighted(mine.lowest, other.lowest)
                ),
                average: AnalysisContent.Metric(
                    value: formatter(mine.average),
                    isHighlighted: isHighlighted(mine.average, other.average)
                ),
                maximum: AnalysisContent.Metric(
                    value: formatter(mine.peak),
                    isHighlighted: isHighlighted(mine.peak, other.peak)
                ),
                meaning: meaningGenerator(out)
            )
        }
    }

    private func makeSeries(_ valueExtractor: (DayPoint) -> Double) -> [AnalysisContent.Series] {
        [LayoutID.two, .one].map { layout in
            let points = outcome(for: layout).dayPoints.map {
                AnalysisContent.Series.Point(hour: $0.hour, value: valueExtractor($0))
            }
            return AnalysisContent.Series(layout: layout, points: points)
        }
    }

    /// The count is the most spots stuck at the same moment, which can be fewer than the spots marked on the plan.
    private func atOnce(_ count: Int) -> String {
        count > 1 ? " at once" : ""
    }

    private func spotsWord(_ count: Int) -> String {
        count == 1 ? "spot" : "spots"
    }

    private func jamMeaning(_ m: Double, window: Double) -> String {
        if m >= 0.7 * window {
            return "People stay stuck most of the time"
        } else if m >= 0.3 * window {
            return "People get stuck now and then"
        } else if m >= 0.025 * window && m >= 0.25 {
            return "People get stuck only briefly"
        } else {
            return "Nobody gets stuck"
        }
    }

    static func formatCountOrAvg(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    static func formatHalfMinutes(_ value: Double) -> String {
        let rounded = (value * 2.0).rounded() / 2.0
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return rounded.formatted(.number.precision(.fractionLength(1)))
    }

    static func formatTableMinutes(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    static func formatDecimal1(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    static func axisMax(_ values: [Double], step: Double, minimum: Double) -> Double {
        let highest = values.max() ?? 0
        let stepped = (highest / step).rounded(.up) * step
        return max(stepped, minimum)
    }
}

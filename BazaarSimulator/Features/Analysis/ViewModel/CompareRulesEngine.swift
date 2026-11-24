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

    // MARK: - 1. Stuck Spots

    private func buildCongestionPoints() -> AnalysisContent {
        // On the average over the whole simulation, the same as the Best Layout summary.
        let win = pickWinner(
            primary: { Self.rounded1($0.averageStuckSpots) },
            tieBreak: { $0.Cavg },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)
        // Shown to the nearest whole number: 1.3 spots on average reads as 1 spot.
        let avgWin = Self.formatCountOrAvg(oWin.averageStuckSpots.rounded())
        let avgLose = Self.formatCountOrAvg(oLose.averageStuckSpots.rounded())

        func spots(_ text: String) -> String { "\(text) \(text == "1" ? "spot" : "spots")" }
        let headline = avgWin == avgLose
            ? (oWin.averageStuckSpots.rounded() == 0
                ? "Neither layout has spots where people get stuck, even on average."
                : "On average, both layouts have \(spots(avgWin)) where people get stuck at once.")
            : oWin.averageStuckSpots.rounded() == 0
            ? "On average, nobody gets stuck in \(oWin.name). \(oLose.name) has \(spots(avgLose))."
            : "On average, people get stuck in only \(spots(avgWin)) in \(oWin.name). "
                + "\(oLose.name) has \(spots(avgLose))."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let c = out.C
            let average = out.averageStuckSpots.rounded()
            let worst = out.worstSpot
            let bullets: [String]
            if c == 0 {
                bullets = ["Busiest at Spot \(worst.number)", "Nobody gets stuck"]
            } else if c == 1 {
                bullets = ["Only at Spot \(worst.number)", "Up to \(worst.peakVisitors) people there"]
            } else {
                bullets = ["Worst at Spot \(worst.number)", "Up to \(worst.peakVisitors) people there"]
            }
            return AnalysisContent.Tile(
                layout: layout,
                value: "\(Self.formatCountOrAvg(average)) \(average == 1 ? "spot" : "spots")",
                caption: "where people get stuck",
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

        // The axis goes up to the most spots stuck at once in either of the two layouts, not to every spot marked.
        let stuckAtOnce = LayoutID.allCases.flatMap { layout in
            outcome(for: layout).dayPoints.map { Double($0.jammedSpots) }
        }
        let maxSpots = max(stuckAtOnce.max() ?? 0, 1)

        var content = AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "exclamationmark.triangle.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Stuck Spots by Layout",
            chartTitle: "Stuck Spots through the day",
            yAxisMaximum: maxSpots,
            yAxisStride: 1,
            series: makeInsightSeries { Double($0.jammedSpots) },
            infoQuestion: "What is a stuck spot?",
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
        content.valueText = { value in "\(Int(value.rounded())) \(Int(value.rounded()) == 1 ? "spot" : "spots")" }
        return withDay(content) { Double($0.jammedSpots) }
    }

    // MARK: - 2. Time Stuck

    private func buildCongestionDuration() -> AnalysisContent {
        // On the average over the whole simulation, the same as the Best Layout summary.
        let win = pickWinner(
            primary: { Self.rounded1($0.averageStuckMinutes) },
            tieBreak: { $0.Msum },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)

        let window = Self.formatHalfMinutes(windowMinutes)
        // Shown to the nearest whole minute.
        let avgWin = oWin.averageStuckMinutes.rounded()
        let avgLose = oLose.averageStuckMinutes.rounded()
        let textWin = Self.formatCountOrAvg(avgWin), textLose = Self.formatCountOrAvg(avgLose)

        let headline = textWin == textLose
            ? (avgLose < 0.05
                ? "Nobody gets stuck in either layout, even on average."
                : "On average, people at the worst spot are stuck about \(textWin) min in both layouts.")
            : avgWin < 0.05
            ? "On average, nobody gets stuck in \(oWin.name). "
                + "In \(oLose.name), people at the worst spot are stuck about \(textLose) min."
            : "On average, people at the worst spot are stuck about \(textWin) min in \(oWin.name). "
                + "In \(oLose.name), about \(textLose) min."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let qualifying = out.spots
                .filter { $0.stuckMin >= 0.5 }
                .sorted { $0.stuckMin > $1.stuckMin }
                .prefix(2)
                .map { "Spot \($0.number): \(Self.formatCountOrAvg($0.stuckMin.rounded())) min" }
            let bullets = qualifying.isEmpty ? ["Nobody gets stuck"] : Array(qualifying)
            return AnalysisContent.Tile(
                layout: layout,
                value: Self.formatCountOrAvg(out.averageStuckMinutes.rounded()),
                caption: "stuck at the worst spot",
                bullets: bullets,
                unit: "min"
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

        var content = AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "clock.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Time Stuck by Layout",
            chartTitle: "Time Stuck through the day",
            yAxisMaximum: windowMinutes,
            yAxisStride: windowMinutes / 2,
            series: makeInsightSeries { $0.heavyMinutes },
            infoQuestion: "What does time stuck mean?",
            explanation: "How long people stay stuck at the worst spot in the busiest time.",
            unit: "min",
            measure: "Minutes people stay stuck, out of \(window)",
            facts: [
                AnalysisContent.Fact(symbol: "person.3.fill", text: "Stuck means grade E or F"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Checked at each spot all day"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Shorter is better"),
            ]
        )
        content.axisLabel = { "\(Self.formatHalfMinutes($0)) min" }
        content.valueText = { "\(Self.formatCountOrAvg($0.rounded())) min" }
        return withDay(content) { $0.heavyMinutes }
    }

    // MARK: - 3. Crowd Density

    private func buildCrowdDensity() -> AnalysisContent {
        // On the average over the whole simulation, the same as the Best Layout summary.
        let win = pickWinner(
            primary: { $0.averageDensity },
            tieBreak: { _ in 0 },
            lowerIsBetter: true
        )
        let lose = win.other
        let oWin = outcome(for: win)
        let oLose = outcome(for: lose)
        let winLevel = SeverityGrade.grade(forDensity: oWin.averageDensity).crowdLevel
        let loseLevel = SeverityGrade.grade(forDensity: oLose.averageDensity).crowdLevel

        let headline = winLevel == loseLevel
            ? "On average, at its most crowded spot, both layouts are \(winLevel)."
            : "On average, at its most crowded spot, \(oWin.name) is \(winLevel), while \(oLose.name) is \(loseLevel)."

        let tiles = LayoutID.allCases.map { layout -> AnalysisContent.Tile in
            let out = outcome(for: layout)
            let grade = SeverityGrade.grade(forDensity: out.averageDensity)
            return AnalysisContent.Tile(
                layout: layout,
                value: grade.crowdLevel,
                caption: "at its most crowded spot",
                bullets: [
                    grade.crowdMeaning,
                    "Up to \(out.worstSpot.peakVisitors) people there"
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

        var content = AnalysisContent(
            recommended: win,
            headline: headline,
            symbol: "person.3.fill",
            tiles: tiles,
            rows: rows,
            tableTitle: "Crowd Level by Layout",
            chartTitle: "Crowd Level through the day",
            yAxisMaximum: Double(SeverityGrade.allCases.count),
            yAxisStride: 1,
            series: makeInsightSeries { $0.worstDensity },
            infoQuestion: "What do the crowd levels mean?",
            explanation: "How crowded the busiest spot gets, from calm to jammed.",
            unit: "per m²",
            measure: "People per m² at the busiest spot",
            facts: [
                AnalysisContent.Fact(symbol: "person.2.fill", text: "About 2 per m²: shoulders touch"),
                AnalysisContent.Fact(symbol: "mappin.and.ellipse", text: "Checked at the busiest spot all day"),
                AnalysisContent.Fact(symbol: "checkmark.circle", text: "Lower is better"),
            ]
        )
        // The axis names every level, from Very Low to Very High, and gives each the same room. A level's name is set
        // in the middle of its band, and a density is placed inside its band in proportion to where it lies in it.
        content.plotValue = Self.crowdLevelPlace
        content.axisTicks = SeverityGrade.allCases.map { Double($0.rawValue) + 0.5 }
        content.axisLabel = { SeverityGrade(rawValue: Int($0))?.crowdLevel ?? "" }
        content.valueText = { "\(Self.formatDecimal1($0)) per m²" }
        return withDay(content) { $0.worstDensity }
    }

    /// Where a density sits on the crowd level axis: the level's place, then how far through its band the density is.
    /// The last level has no upper limit, so it is given as much room as the densities seen up to 0.6 above it.
    static func crowdLevelPlace(_ density: Double) -> Double {
        let grade = SeverityGrade.grade(forDensity: density)
        let lower = grade.lowerDensity
        let upper = grade.upperDensity ?? lower + 0.6
        let share = min(max((density - lower) / (upper - lower), 0), 1)
        return Double(grade.rawValue) + share
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

    // MARK: - Through the day

    /// Every hour the day was sampled at, which is what the Insights chart plots.
    private var chartHours: [Double] {
        outcome(for: .one).dayPoints.map(\.hour).sorted()
    }

    /// The three moments the chart names and the sentence under it talks about: the start of the day, the busiest
    /// time, and the last sample.
    private var keyHours: [Double] {
        let hours = outcome(for: .one).dayPoints.map(\.hour).sorted()
        guard let first = hours.first, let last = hours.last else { return [] }
        let peak = peakHourValue.flatMap { target in hours.min { abs($0 - target) < abs($1 - target) } }
        var result = [first]
        if let peak, peak != first, peak != last { result.append(peak) }
        if last != first { result.append(last) }
        return result
    }

    /// The busiest time as an hour, read from its "HH:mm" text.
    private var peakHourValue: Double? {
        let parts = peakHourText.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] + parts[1] / 60
    }

    private func makeInsightSeries(_ value: (DayPoint) -> Double) -> [AnalysisContent.Series] {
        let hours = chartHours
        return [LayoutID.two, .one].map { layout in
            let points = outcome(for: layout).dayPoints
                .filter { point in hours.contains { abs($0 - point.hour) < 1e-9 } }
                .map { AnalysisContent.Series.Point(hour: $0.hour, value: value($0)) }
            return AnalysisContent.Series(layout: layout, points: points)
        }
    }

    /// Adds what the chart needs to read as a day: the words under the morning, the busiest time and the evening, and
    /// who does better when. The other hours are labelled with their time.
    private func withDay(_ content: AnalysisContent, value: (DayPoint) -> Double) -> AnalysisContent {
        var result = content
        let hours = keyHours
        result.peakHour = peakHourValue.flatMap { target in hours.min { abs($0 - target) < abs($1 - target) } }
        for (index, hour) in hours.enumerated() {
            let time = TimeRange.format(Int((hour * 60).rounded()))
            let word = hour == result.peakHour ? "Busiest time" : index == 0 ? "Morning" : "Evening"
            result.hourLabels[hour] = "\(word) (\(time))"
        }
        result.comparison = comparisonSentence(value)
        return result
    }

    /// "Layout 2 does better all day: in the morning, at the busiest time and in the evening."
    private func comparisonSentence(_ value: (DayPoint) -> Double) -> String {
        let hours = keyHours
        guard !hours.isEmpty else { return "" }
        let slots = hours.enumerated().map { index, hour -> (phrase: String, winner: LayoutID?) in
            func point(_ layout: LayoutID) -> Double {
                outcome(for: layout).dayPoints.first { abs($0.hour - hour) < 1e-9 }.map(value) ?? 0
            }
            let first = point(.one), second = point(.two)
            let phrase = hour == peakHourValue.flatMap { target in hours.min { abs($0 - target) < abs($1 - target) } }
                ? "at the busiest time" : index == 0 ? "in the morning" : "in the evening"
            if abs(first - second) < 1e-9 { return (phrase, nil) }
            return (phrase, first < second ? .one : .two)
        }
        func joined(_ phrases: [String]) -> String {
            phrases.count > 1 ? phrases.dropLast().joined(separator: ", ") + " and " + phrases[phrases.count - 1] : phrases.first ?? ""
        }
        let winners = Set(slots.compactMap(\.winner))
        if winners.isEmpty { return "Both layouts do the same all day." }
        if slots.allSatisfy({ $0.winner != nil }), winners.count == 1, let only = winners.first {
            return "\(outcome(for: only).name) does better all day: \(joined(slots.map(\.phrase)))."
        }
        var sentences: [String] = []
        for layout in LayoutID.allCases {
            let wins = slots.filter { $0.winner == layout }.map(\.phrase)
            if !wins.isEmpty { sentences.append("\(outcome(for: layout).name) does better \(joined(wins)).") }
        }
        let ties = slots.filter { $0.winner == nil }.map(\.phrase)
        if !ties.isEmpty { sentences.append("They are level \(joined(ties)).") }
        return sentences.joined(separator: " ")
    }

    static func minutesText(_ value: Double) -> String {
        let text = formatHalfMinutes(value)
        return "\(text) \(text == "1" ? "minute" : "minutes")"
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

    /// Rounded to one decimal, as the page shows an average, so the winner is chosen on what is shown.
    static func rounded1(_ value: Double) -> Double {
        (value * 10).rounded() / 10
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

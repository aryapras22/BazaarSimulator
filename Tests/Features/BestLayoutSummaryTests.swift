import CoreGraphics
import Foundation
import Testing
@testable import BazaarSimulator

@Suite("BestLayoutSummaryTests")
struct BestLayoutSummaryTests {
    private func spot(_ number: Int, peak: Double, stuck: Double) -> SpotOutcome {
        SpotOutcome(
            number: number, name: "Spot \(number)", cause: "", location: .zero,
            lowestDensity: peak / 3, peakDensity: peak, peakVisitors: 20, stuckMin: stuck
        )
    }

    private func outcome(_ layout: LayoutID, spots: [SpotOutcome]) -> LayoutOutcome {
        LayoutOutcome(
            layout: layout, name: layout.name, windowMinutes: 10, spots: spots,
            dayPoints: [
                DayPoint(hour: 10, worstDensity: 0.5, heavyMinutes: 0, jammedSpots: 0, flowRate: 9),
                // The day's values follow the spots, so a layout with worse spots also averages worse over the day.
                DayPoint(
                    hour: 14, worstDensity: spots.map(\.peakDensity).max() ?? 0,
                    heavyMinutes: spots.max { $0.peakDensity < $1.peakDensity }?.stuckMin ?? 0,
                    jammedSpots: LayoutOutcome.stuckCounts(of: spots).peak, flowRate: 12
                )
            ]
        )
    }

    private func summary(busy: [SpotOutcome], calm: [SpotOutcome]) -> BestLayoutSummary {
        let outcomes: [LayoutID: LayoutOutcome] = [.one: outcome(.one, spots: busy), .two: outcome(.two, spots: calm)]
        let engine = CompareRulesEngine(outcomes: outcomes, peakHourText: "14:00", windowMinutes: 10)
        return BestLayoutSummary(engine: engine, outcomes: outcomes)
    }

    @Test("The calmer layout is best, and the sentence lists what it does better")
    func calmerLayoutWins() {
        let result = summary(
            busy: [spot(1, peak: 2.9, stuck: 6), spot(2, peak: 2.4, stuck: 4), spot(3, peak: 2.2, stuck: 3)],
            calm: [spot(1, peak: 0.5, stuck: 0)]
        )

        #expect(result.best == .two)
        #expect(result.checks.map(\.label) == ["Stuck Spots", "Crowd Level", "Time Stuck"])
        #expect(result.sentence == "Fewer stuck spots, calmer crowds and less time stuck.")
        #expect(result.checks.allSatisfy { $0.winner == .two })
    }

    @Test("A check where both layouts show the same value is not named as a strength")
    func equalChecksAreTies() {
        let same = [spot(1, peak: 2.9, stuck: 6), spot(2, peak: 2.4, stuck: 4)]
        #expect(summary(busy: same, calm: same).sentence == "Both layouts do the same on all three checks.")

        // Same spots stuck and the same grade, and only the time stuck differs.
        let result = summary(busy: same, calm: [spot(1, peak: 2.9, stuck: 3), spot(2, peak: 2.4, stuck: 2)])
        #expect(result.best == .two)
        #expect(result.sentence == "Less time stuck.")
    }

    @Test("Each check shows the best layout's value and how the other layout did")
    func valuesAndCaptions() throws {
        let result = summary(
            busy: [spot(1, peak: 2.9, stuck: 6), spot(2, peak: 2.4, stuck: 4)],
            calm: [spot(1, peak: 0.5, stuck: 0)]
        )

        let points = try #require(result.checks.first { $0.tab == .congestionPoints })
        #expect(points.values[.two]?.text == "0")
        #expect(points.values[.two]?.unit == "spots")
        #expect(result.caption(for: points).hasPrefix("Layout 1: "))

        let level = try #require(result.checks.first { $0.tab == .crowdDensity })
        #expect(level.values[.two]?.unit == "")
        #expect(level.values[.two]?.text.isEmpty == false)
    }

    @Test("A huge gap in time stuck outweighs a one spot lead in stuck spots")
    func hugeTimeStuckGapDecides() {
        // Layout 1 has fewer spots stuck at once (1 against 2), but its worst spot is stuck for the whole 10 minutes,
        // against none in layout 2. The densities are in the same grade.
        let result = summary(
            busy: [spot(1, peak: 1.0, stuck: 10)],
            calm: [spot(1, peak: 1.0, stuck: 0), spot(2, peak: 1.0, stuck: 0)]
        )
        let time = result.checks.first { $0.tab == .congestionDuration }
        #expect(time?.isHuge == true)
        #expect(result.best == .two)
    }

    @Test("A small gap in time stuck does not outweigh stuck spots")
    func smallGapDoesNotOverrule() {
        let result = summary(
            busy: [spot(1, peak: 1.0, stuck: 5)],
            calm: [spot(1, peak: 1.0, stuck: 4), spot(2, peak: 1.0, stuck: 4)]
        )
        // Layout 1: 1 stuck spot against 2 (margin 0.5, huge) and 0.5 minutes more stuck on average (margin 0.05).
        #expect(result.best == .one)
    }

    @Test("Strengths read as one sentence")
    func listing() {
        #expect(BestLayoutSummary.list(["a", "b", "c"]) == "a, b and c")
        #expect(BestLayoutSummary.list(["a", "b"]) == "a and b")
        #expect(BestLayoutSummary.list(["a"]) == "a")
        #expect(BestLayoutSummary.list([]) == "")
        #expect(BestLayoutSummary.capitalized("fewer stuck spots") == "Fewer stuck spots")
    }
}

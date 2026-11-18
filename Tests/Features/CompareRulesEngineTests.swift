import CoreGraphics
import Foundation
import Testing
@testable import BazaarSimulator

@Suite("CompareRulesEngineTests")
struct CompareRulesEngineTests {

    private func makeFixtureOutcomes() -> [LayoutID: LayoutOutcome] {
        let spots1 = [
            SpotOutcome(
                number: 1, name: "West Aisle", cause: "",
                location: .zero, lowestDensity: 0.7, peakDensity: 2.1,
                peakVisitors: 38, stuckMin: 3.5
            ),
            SpotOutcome(
                number: 2, name: "Food Corner", cause: "",
                location: .zero, lowestDensity: 1.1, peakDensity: 2.9,
                peakVisitors: 45, stuckMin: 6.0
            ),
            SpotOutcome(
                number: 3, name: "South East Corner", cause: "",
                location: .zero, lowestDensity: 0.6, peakDensity: 1.5,
                peakVisitors: 21, stuckMin: 1.5
            ),
        ]
        let dayPoints1 = [
            DayPoint(hour: 10, worstDensity: 0.8, heavyMinutes: 0, jammedSpots: 0, flowRate: 9),
            DayPoint(hour: 14, worstDensity: 2.9, heavyMinutes: 6.0, jammedSpots: 3, flowRate: 13),
            DayPoint(hour: 18, worstDensity: 1.2, heavyMinutes: 2, jammedSpots: 1, flowRate: 11),
        ]
        let out1 = LayoutOutcome(
            layout: .one, name: "Layout 1",
            windowMinutes: 10.0, spots: spots1, dayPoints: dayPoints1
        )

        let spots2 = [
            SpotOutcome(
                number: 1, name: "Center Aisle", cause: "",
                location: .zero, lowestDensity: 0.4, peakDensity: 1.2,
                peakVisitors: 20, stuckMin: 0.8
            ),
        ]
        let dayPoints2 = [
            DayPoint(hour: 10, worstDensity: 0.6, heavyMinutes: 0, jammedSpots: 0, flowRate: 9),
            DayPoint(hour: 14, worstDensity: 1.2, heavyMinutes: 0.8, jammedSpots: 1, flowRate: 20),
            DayPoint(hour: 18, worstDensity: 0.5, heavyMinutes: 0, jammedSpots: 0, flowRate: 14),
        ]
        let out2 = LayoutOutcome(
            layout: .two, name: "Layout 2",
            windowMinutes: 10.0, spots: spots2, dayPoints: dayPoints2
        )

        return [.one: out1, .two: out2]
    }

    @Test("Congestion Points tab picks layout with lower C as winner")
    func congestionPointsWinner() {
        let outcomes = makeFixtureOutcomes()
        let engine = CompareRulesEngine(outcomes: outcomes, peakHourText: "14:00")
        let content = engine.content(for: .congestionPoints)

        #expect(content.recommended == .two)
        #expect(content.headline == "At the busiest time, people get stuck in only 1 spot. Layout 1 has 3.")
        #expect(content.chartTitle == "Stuck Spots through the day")
        #expect(content.symbol == "exclamationmark.triangle.fill")
        #expect(content.tiles.count == 2)
        #expect(content.tiles[0].bullets[0].hasPrefix("Worst at Spot"))
        #expect(content.tiles[1].bullets[0].hasPrefix("Only at Spot"))
        #expect(content.tiles[0].caption == "where people get stuck")
        #expect(content.facts.count == 3)
    }

    @Test("Congestion Duration tab picks layout with lower M")
    func congestionDurationWinner() {
        let outcomes = makeFixtureOutcomes()
        let engine = CompareRulesEngine(outcomes: outcomes, peakHourText: "14:00")
        let content = engine.content(for: .congestionDuration)

        #expect(content.recommended == .two)
        #expect(content.headline.hasPrefix("In the busiest 10 minutes, people at the worst spot are stuck for about"))
        #expect(content.headline.contains("In Layout 1, they're stuck"))
        #expect(content.symbol == "clock.fill")
        #expect(content.tiles[0].value == "6")
        #expect(content.tiles[0].unit == "min")
        #expect(content.tiles[1].value == "1")
        #expect(content.rows.count == 2)
    }

    @Test("Crowd Density tab picks layout with lower peak density")
    func crowdDensityWinner() {
        let outcomes = makeFixtureOutcomes()
        let engine = CompareRulesEngine(outcomes: outcomes, peakHourText: "14:00")
        let content = engine.content(for: .crowdDensity)

        #expect(content.recommended == .two)
        let level1 = SeverityGrade.grade(forDensity: 2.9).crowdLevel
        let level2 = SeverityGrade.grade(forDensity: 1.2).crowdLevel

        #expect(content.headline == "At its most crowded spot, Layout 2 is \(level2), while Layout 1 is \(level1).")
        #expect(content.symbol == "person.3.fill")
        #expect(content.tiles[0].value == level1)
        #expect(content.tiles[1].value == level2)
        #expect(content.chartTitle == "Crowd Level through the day")
        #expect(content.infoQuestion == "What do the crowd levels mean?")
    }

    @Test("Flow Rate tab evaluates steady swing and minimum flow")
    func flowRateWinner() {
        let outcomes = makeFixtureOutcomes()
        let engine = CompareRulesEngine(outcomes: outcomes, peakHourText: "14:00")
        let content = engine.content(for: .flowRate)

        #expect(content.symbol == "figure.run")
        #expect(content.tiles.count == 2)
        #expect(content.rows.count == 2)
        #expect(content.tableTitle == "Flow Rate by Layout")
        #expect(content.chartTitle == "Flow Rate Throughout the Day")
    }

    @Test("A full tie on Crowd Density goes to Layout 1, whatever the spot numbers")
    func crowdDensityTieGoesToLayoutOne() {
        func spot(_ number: Int) -> SpotOutcome {
            SpotOutcome(
                number: number, name: "Spot", cause: "", location: .zero,
                lowestDensity: 0.5, peakDensity: 1.5, peakVisitors: 10, stuckMin: 2
            )
        }
        let one = LayoutOutcome(layout: .one, name: "Layout 1", windowMinutes: 10, spots: [spot(5)], dayPoints: [])
        let two = LayoutOutcome(layout: .two, name: "Layout 2", windowMinutes: 10, spots: [spot(1)], dayPoints: [])
        let engine = CompareRulesEngine(outcomes: [.one: one, .two: two])
        #expect(engine.content(for: .crowdDensity).recommended == .one)
    }
}

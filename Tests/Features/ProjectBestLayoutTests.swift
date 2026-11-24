import CoreGraphics
import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ProjectBestLayoutTests")
struct ProjectBestLayoutTests {
    private func outcome(peak: Double, stuck: Double, copies: Int = 1, name: String = "Layout") -> LayoutOutcome {
        let spots = (1...copies).map { number in
            SpotOutcome(
                number: number, name: "Spot \(number)", cause: "", location: .zero,
                lowestDensity: peak / 3, peakDensity: peak, peakVisitors: 20, stuckMin: stuck
            )
        }
        return LayoutOutcome(
            layout: .one, name: name, windowMinutes: 10, spots: spots,
            dayPoints: [
                DayPoint(hour: 10, worstDensity: 0.5, heavyMinutes: 0, jammedSpots: 0, flowRate: 9),
                DayPoint(
                    hour: 14, worstDensity: peak, heavyMinutes: stuck,
                    jammedSpots: LayoutOutcome.stuckCounts(of: spots).peak, flowRate: 12
                )
            ]
        )
    }

    @Test("The best of three layouts is found even when it is not one of the first two")
    func bestOfAllLayouts() {
        let busy = UUID(), middle = UUID(), calm = UUID()
        let best = ProjectBestLayout.best(
            of: [
                ProjectOutcome(layoutID: busy, outcome: outcome(peak: 2.9, stuck: 6, copies: 3)),
                ProjectOutcome(layoutID: middle, outcome: outcome(peak: 1.6, stuck: 3, copies: 2)),
                ProjectOutcome(layoutID: calm, outcome: outcome(peak: 0.5, stuck: 0))
            ],
            peakHourText: "14:00", windowMinutes: 10
        )
        #expect(best == calm)
    }

    @Test("With two layouts it is the one the Best Layout summary names")
    func twoLayouts() {
        let busy = UUID(), calm = UUID()
        let best = ProjectBestLayout.best(
            of: [
                ProjectOutcome(layoutID: busy, outcome: outcome(peak: 2.9, stuck: 6, copies: 3)),
                ProjectOutcome(layoutID: calm, outcome: outcome(peak: 0.5, stuck: 0))
            ],
            peakHourText: "14:00", windowMinutes: 10
        )
        #expect(best == calm)
    }

    @Test("One layout is its own best, and no layouts have none")
    func fewLayouts() {
        let only = UUID()
        let single = ProjectBestLayout.best(
            of: [ProjectOutcome(layoutID: only, outcome: outcome(peak: 1, stuck: 1))],
            peakHourText: "14:00", windowMinutes: 10
        )
        #expect(single == only)
        #expect(ProjectBestLayout.best(of: [], peakHourText: "14:00", windowMinutes: 10) == nil)
    }

    @Test("The card names the best layout and says whether the layout on the other card does better on a check")
    func summaryAgainstTheOtherCard() throws {
        // Layout 1 has fewer spots stuck at once, but its worst spot is stuck for the whole window. Layout 2 wins
        // overall on that, and Layout 3 is worse on every check.
        func entry(_ peak: Double, _ stuck: Double, _ copies: Int, _ name: String) -> ProjectOutcome {
            ProjectOutcome(
                layoutID: UUID(), outcome: outcome(peak: peak, stuck: stuck, copies: copies, name: name)
            )
        }
        let first = entry(1.0, 10, 1, "Layout 1")
        let second = entry(1.0, 0, 2, "Layout 2")
        let third = entry(2.5, 8, 3, "Layout 3")
        let bestID = try #require(ProjectBestLayout.best(
            of: [first, second, third], peakHourText: "14:00", windowMinutes: 10
        ))
        #expect(bestID == second.layoutID)

        // Against the layout on the other card, and not against every layout.
        let againstFirst = ProjectBestSummary(best: second, against: first, place: nil)
        #expect(againstFirst.name == "Layout 2")
        let spots = try #require(againstFirst.checks.first { $0.tab == .congestionPoints })
        #expect(!spots.isBest)
        #expect(spots.note == "Layout 1 has fewer stuck spots.")
        let time = try #require(againstFirst.checks.first { $0.tab == .congestionDuration })
        #expect(time.isBest)
        #expect(time.note == nil)

        // Against a layout that is worse everywhere, the best layout does best on every check.
        let againstThird = ProjectBestSummary(best: second, against: third, place: nil)
        #expect(againstThird.checks.allSatisfy { $0.isBest && $0.note == nil })
    }
}

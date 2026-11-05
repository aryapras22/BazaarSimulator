import Foundation
import Testing
@testable import BazaarSimulator

@Suite("SimulationRunnerTests")
struct SimulationRunnerTests {
    private func parameters(
        total: Int = 5000,
        hours: TimeRange = TimeRange(startMinute: 10 * 60, endMinute: 21 * 60),
        peaks: [TimeRange] = []
    ) -> EventParameters {
        EventParameters(
            totalVisitors: total,
            eventHours: hours,
            peakPeriods: peaks,
            bazaarTypeID: "one",
            mix: VisitorMix(equalSplitOf: ["a", "b"]),
            groupSize: 5
        )
    }

    @Test("Without parameters the simulator's own defaults are used")
    func defaults() {
        let result = SimulationRunner.run(parameters: nil)
        #expect(result.peakHourText == "14:00")
        #expect(result.windowMinutes == 10)
        #expect(result.sampleHours == [10, 12, 14, 16, 18])
    }

    @Test("Event hours set the sample hours, every 2 hours, with the end added when a full hour past")
    func sampleHoursFollowEventHours() {
        let result = SimulationRunner.run(parameters: parameters())
        #expect(result.sampleHours == [10, 12, 14, 16, 18, 20, 21])
    }

    @Test("The first peak period sets the busiest hour, and it is a sample hour")
    func peakFromParameters() {
        let peak = TimeRange(startMinute: 16 * 60, endMinute: 18 * 60)
        let result = SimulationRunner.run(parameters: parameters(peaks: [peak]))
        #expect(result.peakHourText == "16:00")
        #expect(result.sampleHours.contains(16))
    }

    @Test("A peak period that starts off the hour still becomes a sample hour")
    func offGridPeak() {
        let peak = TimeRange(startMinute: 15 * 60, endMinute: 16 * 60)
        let result = SimulationRunner.run(parameters: parameters(peaks: [peak]))
        #expect(result.peakHourText == "15:00")
        #expect(result.sampleHours == [10, 12, 14, 15, 16, 18, 20, 21])
    }

    @Test("A peak period outside the event falls back to the simulator's 14:00")
    func peakOutsideEvent() {
        let early = TimeRange(startMinute: 6 * 60, endMinute: 8 * 60)
        #expect(SimulationRunner.run(parameters: parameters(peaks: [early])).peakHourText == "14:00")
    }

    @Test("The busiest window always fits before closing")
    func peakKeepsWindowInside() {
        let late = TimeRange(startMinute: 20 * 60 + 55, endMinute: 22 * 60)
        let hours = TimeRange(startMinute: 10 * 60, endMinute: 21 * 60)
        let result = SimulationRunner.run(parameters: parameters(hours: hours, peaks: [late]))
        #expect(result.peakHourText == "20:50")
    }

    @Test("Day values at the busiest hour equal the window values")
    func dayMatchesWindowAtPeak() throws {
        let result = SimulationRunner.run(parameters: parameters(peaks: [TimeRange(startMinute: 15 * 60, endMinute: 17 * 60)]))
        for outcome in result.outcomes.values {
            let atPeak = try #require(outcome.dayPoints.first { $0.hour == 15 })
            #expect(atPeak.worstDensity == outcome.D)
            #expect(atPeak.heavyMinutes == outcome.M)
            #expect(atPeak.jammedSpots == outcome.C)
        }
    }

    @Test("Every layout has one day point per sample hour")
    func dayPointsMatchSampleHours() {
        let result = SimulationRunner.run(parameters: parameters())
        for outcome in result.outcomes.values {
            #expect(outcome.dayPoints.map(\.hour) == result.sampleHours)
        }
    }

    @Test("More visitors per hour make the busiest spot denser")
    func moreVisitorsMeansDenser() {
        let quiet = SimulationRunner.run(parameters: parameters(total: 2000))
        let busy = SimulationRunner.run(parameters: parameters(total: 9000))
        #expect(busy.outcomes[.one]!.D > quiet.outcomes[.one]!.D)
    }

    @Test("A shorter event packs the same visitors into fewer hours")
    func shorterEventMeansDenser() {
        let long = SimulationRunner.run(parameters: parameters(hours: TimeRange(startMinute: 8 * 60, endMinute: 20 * 60)))
        let short = SimulationRunner.run(parameters: parameters(hours: TimeRange(startMinute: 12 * 60, endMinute: 16 * 60)))
        #expect(short.outcomes[.one]!.D > long.outcomes[.one]!.D)
    }

    @Test("The default catalog parameters give the same busiest spot as having no parameters")
    func defaultParametersMatchSimulatorDefaults() {
        let withDefaults = SimulationRunner.run(parameters: parameters())
        let without = SimulationRunner.run(parameters: nil)
        #expect(withDefaults.outcomes[.one]!.D == without.outcomes[.one]!.D)
    }

    @Test("Hours with no length fall back to the simulator's event hours")
    func invalidHours() {
        let broken = parameters(hours: TimeRange(startMinute: 600, endMinute: 600))
        #expect(SimulationRunner.run(parameters: broken).sampleHours == [10, 12, 14, 16, 18])
    }
}

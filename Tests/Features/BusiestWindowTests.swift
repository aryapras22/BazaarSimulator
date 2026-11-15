import Foundation
import Testing
@testable import BazaarSimulator

@Suite("BusiestWindowTests")
struct BusiestWindowTests {
    private let hours = TimeRange(startMinute: 10 * 60, endMinute: 14 * 60)

    /// One spot sampled every 15 seconds, quiet except for a crowded stretch.
    private func analysis(crowdedFromMinute: Int, minutes: Int = 10, crowd: Int = 30) -> LayoutAnalysis {
        let perMinute = 4
        let count = 240 * perMinute
        let people = (0..<count).map { sample -> Int in
            let minute = sample / perMinute
            return (crowdedFromMinute..<crowdedFromMinute + minutes).contains(minute) ? crowd : 2
        }
        let spot = SpotMeasurement(
            number: 1, name: "A", position: SIMD2(1, 1),
            densitySamples: people.map { Float($0) / 10 }, peopleSamples: people
        )
        return LayoutAnalysis(
            layoutID: UUID(), eventStartMinute: hours.startMinute, sampleIntervalSeconds: 15, spots: [spot],
            flowPerMinute: [], simulatedPeople: 100, totalPeople: 100
        )
    }

    @Test("The busiest window starts where the most people were measured")
    func findsTheCrowdedStretch() {
        let start = BusiestWindow.startMinute(in: [analysis(crowdedFromMinute: 90)], hours: hours, windowMinutes: 10)
        #expect(start == hours.startMinute + 90)
    }

    @Test("Layouts are compared in the same window, the one that is busiest for both together")
    func sharedWindow() {
        let early = analysis(crowdedFromMinute: 30)
        let late = analysis(crowdedFromMinute: 150, minutes: 20, crowd: 45)
        let start = BusiestWindow.startMinute(in: [early, late], hours: hours, windowMinutes: 10)
        #expect(start.map { $0 >= hours.startMinute + 150 && $0 < hours.startMinute + 170 } == true)
    }

    @Test("A window that would run past closing is moved back inside the event")
    func staysInsideTheEvent() {
        let start = BusiestWindow.startMinute(in: [analysis(crowdedFromMinute: 235, minutes: 5)], hours: hours, windowMinutes: 10)
        #expect(start.map { $0 + 10 <= hours.endMinute } == true)
    }

    @Test("Nothing measured means no busiest window")
    func nothingMeasured() {
        #expect(BusiestWindow.startMinute(in: [], hours: hours, windowMinutes: 10) == nil)
    }
}

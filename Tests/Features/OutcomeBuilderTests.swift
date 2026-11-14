import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct OutcomeBuilderTests {
    /// Three hours from 10:00, a sample every 10 seconds. Density and people only ever go up.
    private func rampingAnalysis(density: (Int) -> Float = { Float($0) / 1000 }) -> LayoutAnalysis {
        let samples = 3 * 60 * 6
        return LayoutAnalysis(
            layoutID: UUID(),
            eventStartMinute: 600,
            sampleIntervalSeconds: 10,
            spots: [
                SpotMeasurement(
                    number: 1, name: "Aisle", position: SIMD2(12, 6),
                    densitySamples: (0..<samples).map(density),
                    peopleSamples: (0..<samples).map { $0 / 10 }
                )
            ],
            flowPerMinute: (0...180).map(Double.init),
            simulatedPeople: 100,
            totalPeople: 100,
            plan: PlanFrame(origin: .zero, size: SIMD2(24, 12))
        )
    }

    private let schedule = DaySchedule(startHour: 10, peakHour: 11, endHour: 13)

    private func build(_ analysis: LayoutAnalysis) -> LayoutOutcome {
        OutcomeBuilder.build(layoutID: .one, analysis: analysis, schedule: schedule)
    }

    @Test("The busiest window is read from the measurements, ends included")
    func windowSlice() throws {
        let spot = try #require(build(rampingAnalysis()).spots.first)
        #expect(spot.windowDensity.count == 61)
        #expect(Float(spot.windowDensity[0]) == 0.36)
        #expect(Float(spot.windowDensity[60]) == 0.42)
        #expect(spot.peakVisitors == 42)
    }

    @Test("A spot's place on the floor plan is its share of the layout")
    func location() throws {
        let spot = try #require(build(rampingAnalysis()).spots.first)
        #expect(spot.location.x == 0.5)
        #expect(spot.location.y == 0.5)
    }

    @Test("Day values at the busiest hour equal the window values")
    func dayMatchesWindow() throws {
        let outcome = build(rampingAnalysis { _ in 2 })
        let atPeak = try #require(outcome.dayPoints.first { $0.hour == 11 })
        #expect(atPeak.worstDensity == outcome.D)
        #expect(atPeak.heavyMinutes == outcome.M)
        #expect(atPeak.jammedSpots == outcome.C)
        #expect(outcome.M == 10)
        #expect(outcome.C == 1)
    }

    @Test("One day point per sample hour, in order")
    func dayPointHours() {
        #expect(build(rampingAnalysis()).dayPoints.map(\.hour) == [10, 11, 12, 13])
    }

    @Test("A window that would run past closing is moved back to end when the event does")
    func lateWindow() throws {
        let outcome = build(rampingAnalysis())
        let last = try #require(outcome.dayPoints.last)
        #expect(Float(last.worstDensity) == Float(3 * 60 * 6 - 1) / 1000)
    }

    @Test("Flow is the people passing each minute, averaged over the window")
    func flowAverage() throws {
        let atPeak = try #require(build(rampingAnalysis()).dayPoints.first { $0.hour == 11 })
        #expect(atPeak.flowRate == 64.5)
    }

    @Test("Density below the stuck level never counts as stuck")
    func calmFloor() {
        let outcome = build(rampingAnalysis { _ in 0.4 })
        #expect(outcome.C == 0)
        #expect(outcome.M == 0)
    }

    @Test("A result with no spots still builds")
    func noSpots() {
        var analysis = rampingAnalysis()
        analysis = LayoutAnalysis(
            layoutID: analysis.layoutID, eventStartMinute: 600, sampleIntervalSeconds: 10,
            spots: [], flowPerMinute: [], simulatedPeople: 0, totalPeople: 0
        )
        let outcome = build(analysis)
        #expect(outcome.spots.isEmpty)
        #expect(outcome.dayPoints.allSatisfy { $0.worstDensity == 0 && $0.flowRate == 0 })
    }
}

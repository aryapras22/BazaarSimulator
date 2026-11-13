import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("SimulationReplayBuilderTests")
@MainActor
struct SimulationReplayBuilderTests {
    private func run() async -> (SimulationResult, Layout, EventParameters) {
        var parameters = EventParameters()
        parameters.totalVisitors = 40
        parameters.startMinutes = 10 * 60
        parameters.endMinutes = 10 * 60 + 20
        let layout = PreviewLayouts.annyeong()
        let engine = SimulationEngine(layout: layout, settings: parameters.toSimulationSettings(), legend: Legend())
        let result = await engine.runWithRecordedFootage(
            durationMinutes: parameters.durationMinutes, frameIntervalSeconds: 5.0
        )
        return (result, layout, parameters)
    }

    @Test("The analysis measurements are read from the run's own frames")
    func measurementsComeFromTheRun() async {
        let (result, layout, parameters) = await run()
        let measurements = LayoutMeasurementBuilder.build(result: result, layout: layout, parameters: parameters)

        #expect(measurements.simulatedPeople == result.metrics.arrivals)
        #expect(measurements.eventStartMinute == result.startMinutesFromMidnight)
        let finalTotal = Double(result.metrics.arrivals + result.metrics.departed)
        #expect(measurements.flowPerMinute.reduce(0, +) <= finalTotal)
        let ceiling = Float(result.metrics.peakDensity) + 0.001
        for spot in measurements.spots {
            let highest: Float = spot.densitySamples.max() ?? 0
            #expect(spot.peopleSamples.count == spot.densitySamples.count)
            #expect(highest <= ceiling)
        }
    }

    @Test("The replay is the busiest window of the same run, visitor for visitor")
    func replayMatchesTheRun() async {
        let (result, layout, _) = await run()
        let replay = SimulationReplayBuilder.build(
            result: result, layout: layout, windowStartMinute: 605, windowMinutes: 10
        )

        #expect(replay != nil)
        guard let replay else { return }
        #expect(replay.startMinute == 605)
        #expect(replay.frameIntervalSeconds == 5)
        let expectedFrames = 121
        #expect(replay.frames.count == expectedFrames)
        let source = result.frames.first { $0.elapsedSeconds == 5 * 60 }
        let shown = replay.frames.first
        #expect(shown?.visitors.map(\.id) == source?.visitors.map(\.id))
        let shownPeople = shown?.visitors.map(\.people).reduce(0, +)
        let sourcePeople = source?.visitors.map { Int($0.peopleCount) }.reduce(0, +)
        #expect(shownPeople == sourcePeople)
    }

    @Test("Footfall only grows through the window")
    func footfallGrows() async {
        let (result, layout, _) = await run()
        let replay = SimulationReplayBuilder.build(
            result: result, layout: layout, windowStartMinute: 600, windowMinutes: 10
        )
        let totals = replay?.frames.map { $0.footfall.reduce(0) { $0 + Int($1) } } ?? []
        #expect(!totals.isEmpty)
        let pairs = Array(zip(totals, totals.dropFirst()))
        #expect(pairs.allSatisfy { pair in pair.0 <= pair.1 })
    }
}

@Suite("SpotPeopleTests")
@MainActor
struct SpotPeopleTests {
    @Test("People at a spot are the simulated visitors within reach of it, frame by frame")
    func peopleAreCountedFromVisitors() async {
        var parameters = EventParameters()
        parameters.totalVisitors = 60
        parameters.startMinutes = 10 * 60
        parameters.endMinutes = 10 * 60 + 20
        let layout = PreviewLayouts.annyeong()
        let engine = SimulationEngine(layout: layout, settings: parameters.toSimulationSettings(), legend: Legend())
        let result = await engine.runWithRecordedFootage(
            durationMinutes: parameters.durationMinutes, frameIntervalSeconds: 5.0
        )
        let measurements = LayoutMeasurementBuilder.build(result: result, layout: layout, parameters: parameters)

        let stride = LayoutMeasurementBuilder.sampleIntervalSeconds / 5
        for spot in measurements.spots {
            for (sample, count) in spot.peopleSamples.enumerated() {
                let frame = result.frames[sample * stride]
                let near = frame.visitors.filter { simd_distance($0.position, spot.position) <= 3 }
                let expected = near.map { Int($0.peopleCount) }.reduce(0, +)
                #expect(count == expected)
            }
        }
    }
}

import CoreGraphics
import Foundation

/// Reads one layout's simulation measurements into the values the compare rules use: spots in the
/// busiest window, and a day series sampled at the schedule's hours.
///
/// Every number comes from the same measurements, so the day values at the busiest hour equal the
/// window values.
enum OutcomeBuilder {
    static func build(
        layoutID: LayoutID,
        name: String? = nil,
        analysis: LayoutAnalysis,
        schedule: DaySchedule
    ) -> LayoutOutcome {
        let window = schedule.windowMinutes
        let spots = analysis.spots.map { spot in
            let density = slice(spot.densitySamples.map(Double.init), from: schedule.peakMinute, in: analysis, window: window)
            let people = slice(spot.peopleSamples, from: schedule.peakMinute, in: analysis, window: window)
            return SpotOutcome.measured(
                number: spot.number,
                name: spot.name,
                cause: "Up to \(people.max() ?? 0) people at once at the busiest time.",
                location: {
                    let fraction = analysis.plan.fraction(of: spot.position)
                    return CGPoint(x: fraction.x, y: fraction.y)
                }(),
                density: density,
                people: people,
                windowMinutes: window
            )
        }

        return LayoutOutcome(
            layout: layoutID,
            name: name ?? layoutID.name,
            windowMinutes: window,
            spots: spots,
            dayPoints: schedule.sampleHours.map { dayPoint(at: $0, analysis: analysis, window: window) }
        )
    }

    /// The day values for the window that starts at `hour`.
    private static func dayPoint(at hour: Double, analysis: LayoutAnalysis, window: Double) -> DayPoint {
        let startMinute = Int((hour * 60).rounded())
        let spots = analysis.spots.map { spot in
            SpotOutcome.measured(
                number: spot.number,
                name: spot.name,
                cause: "",
                location: .zero,
                density: slice(spot.densitySamples.map(Double.init), from: startMinute, in: analysis, window: window),
                people: slice(spot.peopleSamples, from: startMinute, in: analysis, window: window),
                windowMinutes: window
            )
        }
        let worst = spots.max { first, second in
            first.peakDensity == second.peakDensity ? first.number > second.number : first.peakDensity < second.peakDensity
        }
        return DayPoint(
            hour: hour,
            worstDensity: worst?.peakDensity ?? 0,
            heavyMinutes: worst?.stuckMin ?? 0,
            jammedSpots: LayoutOutcome.stuckCounts(of: spots).peak,
            flowRate: flow(from: startMinute, in: analysis, window: window)
        )
    }

    /// People walking past the doors each minute, averaged over the window.
    private static func flow(from startMinute: Int, in analysis: LayoutAnalysis, window: Double) -> Double {
        let flow = analysis.flowPerMinute
        guard !flow.isEmpty else { return 0 }
        let first = min(max(startMinute - analysis.eventStartMinute, 0), flow.count - 1)
        let last = min(first + Int(window), flow.count)
        let total = flow[first..<last].reduce(0, +)
        return (total / window * 10).rounded() / 10
    }

    /// The samples from `startMinute` for `window` minutes, both ends included. A window that would run
    /// past closing is moved back so it ends when the event does.
    static func slice<Value>(_ samples: [Value], from startMinute: Int, in analysis: LayoutAnalysis, window: Double) -> [Value] {
        guard !samples.isEmpty else { return [] }
        let perMinute = 60 / max(analysis.sampleIntervalSeconds, 1)
        let length = Int(window) * perMinute
        let wanted = (startMinute - analysis.eventStartMinute) * perMinute
        let first = min(max(wanted, 0), max(samples.count - 1 - length, 0))
        let last = min(first + length, samples.count - 1)
        return Array(samples[first...last])
    }
}

import CoreGraphics
import Foundation

struct SimulationResult: Sendable {
    let outcomes: [LayoutID: LayoutOutcome]
    let peakHourText: String
    let windowMinutes: Double
    let sampleHours: [Double]
}

/// Builds the example outcome for both layouts from the project's parameters.
/// Any value the parameters do not give falls back to the simulator's own default below.
enum SimulationRunner {
    typealias Scale = (density: Double, people: Double, flow: Double)

    static let defaultWindowMinutes: Double = 10.0
    static let defaultEventHours = TimeRange(startMinute: 10 * 60, endMinute: 18 * 60)
    static let defaultPeakMinute = 14 * 60
    /// The visitor rate the example spot data was written for: 5000 people over an 11 hour day.
    static let baselineVisitorsPerHour = 5000.0 / 11.0

    static func run(parameters: EventParameters?) -> SimulationResult {
        let window = defaultWindowMinutes
        let hours = resolveEventHours(parameters)
        let peakMinute = resolvePeakMinute(parameters, hours: hours, window: window)
        let day = DaySchedule(
            startHour: Double(hours.startMinute) / 60,
            peakHour: Double(peakMinute) / 60,
            endHour: Double(hours.endMinute) / 60
        )
        let scale = computeScale(parameters: parameters, hours: hours)

        return SimulationResult(
            outcomes: [
                .one: buildLayout1(scale: scale, window: window, day: day),
                .two: buildLayout2(scale: scale, window: window, day: day)
            ],
            peakHourText: TimeRange.format(peakMinute),
            windowMinutes: window,
            sampleHours: day.sampleHours
        )
    }

    // MARK: Parameters, with simulator defaults

    static func resolveEventHours(_ parameters: EventParameters?) -> TimeRange {
        guard let hours = parameters?.eventHours, hours.durationMinutes > 0 else { return defaultEventHours }
        return hours
    }

    /// The first peak period that overlaps the event, else the simulator's 14:00. Always inside the
    /// event hours, and moved earlier if needed so the whole window fits before closing.
    static func resolvePeakMinute(_ parameters: EventParameters?, hours: TimeRange, window: Double) -> Int {
        let earliest = hours.startMinute
        let latest = max(hours.endMinute - Int(window), earliest)
        let requested = parameters?.peakPeriods
            .sorted { $0.startMinute < $1.startMinute }
            .first { $0.endMinute > earliest && $0.startMinute < hours.endMinute }?
            .startMinute ?? defaultPeakMinute
        return min(max(requested, earliest), latest)
    }

    static func computeScale(parameters: EventParameters?, hours: TimeRange) -> Scale {
        guard let params = parameters else { return (density: 1, people: 1, flow: 1) }
        let perHour = Double(max(params.totalVisitors, 100)) / (Double(hours.durationMinutes) / 60)
        let ratio = perHour / baselineVisitorsPerHour
        return (
            density: max(0.7, min(1.4, pow(ratio, 0.35))),
            people: max(0.5, min(2.5, ratio)),
            flow: max(0.6, min(1.8, pow(ratio, 0.4)))
        )
    }

    // MARK: Layouts

    private static func buildLayout1(scale: Scale, window: Double, day: DaySchedule) -> LayoutOutcome {
        let spots = [
            makeSpot(
                number: 1, name: "West Aisle",
                cause: "A narrow aisle between the west chairs and the table blocks.",
                location: CGPoint(x: 0.189, y: 0.143),
                low: 0.7 * scale.density, peak: 2.1 * scale.density,
                visitors: Int((38.0 * scale.people).rounded()), window: window
            ),
            makeSpot(
                number: 2, name: "Food Corner",
                cause: "Every dining table sits along this one side.",
                location: CGPoint(x: 0.163, y: 0.395),
                low: 1.1 * scale.density, peak: 2.9 * scale.density,
                visitors: Int((45.0 * scale.people).rounded()), window: window
            ),
            makeSpot(
                number: 3, name: "South East Corner",
                cause: "Stage crowds meet people turning at the booth corner.",
                location: CGPoint(x: 0.537, y: 0.527),
                low: 0.6 * scale.density, peak: 1.5 * scale.density,
                visitors: Int((21.0 * scale.people).rounded()), window: window
            )
        ]
        return makeOutcome(
            .one, spots: spots, window: window, day: day,
            start: DayValues(worstDensity: 0.8 * scale.density, heavyMinutes: 0, jammedSpots: 0, flowRate: 9 * scale.flow),
            end: DayValues(
                worstDensity: 1.2 * scale.density, heavyMinutes: min(2 * scale.density, window),
                jammedSpots: 1, flowRate: 11 * scale.flow
            ),
            peakFlow: 13 * scale.flow
        )
    }

    private static func buildLayout2(scale: Scale, window: Double, day: DaySchedule) -> LayoutOutcome {
        let spots = [
            makeSpot(
                number: 1, name: "Center Aisle",
                cause: "Four booths around one crossing pull everyone to the same point.",
                location: CGPoint(x: 0.684, y: 0.193),
                low: 0.4 * scale.density, peak: 1.2 * scale.density,
                visitors: Int((20.0 * scale.people).rounded()), window: window
            )
        ]
        return makeOutcome(
            .two, spots: spots, window: window, day: day,
            start: DayValues(worstDensity: 0.6 * scale.density, heavyMinutes: 0, jammedSpots: 0, flowRate: 9 * scale.flow),
            end: DayValues(worstDensity: 0.5 * scale.density, heavyMinutes: 0, jammedSpots: 0, flowRate: 14 * scale.flow),
            peakFlow: 20 * scale.flow
        )
    }

    /// The peak values come from the spots themselves, so the day values at the busiest hour
    /// equal the window values. Only the start and end of the day are example numbers.
    private static func makeOutcome(
        _ layout: LayoutID,
        spots: [SpotOutcome],
        window: Double,
        day: DaySchedule,
        start: DayValues,
        end: DayValues,
        peakFlow: Double
    ) -> LayoutOutcome {
        let draft = LayoutOutcome(
            layout: layout, name: layout.name, windowMinutes: window, spots: spots, dayPoints: []
        )
        let peak = DayValues(
            worstDensity: draft.D,
            heavyMinutes: draft.M,
            jammedSpots: Double(draft.C),
            flowRate: peakFlow
        )
        return LayoutOutcome(
            layout: layout,
            name: layout.name,
            windowMinutes: window,
            spots: spots,
            dayPoints: day.dayPoints(start: start, peak: peak, end: end)
        )
    }

    private static func makeSpot(
        number: Int,
        name: String,
        cause: String,
        location: CGPoint,
        low: Double,
        peak: Double,
        visitors: Int,
        window: Double
    ) -> SpotOutcome {
        SpotOutcome(
            number: number,
            name: name,
            cause: cause,
            location: location,
            lowestDensity: low,
            peakDensity: peak,
            peakVisitors: visitors,
            stuckMin: SpotOutcome.computeStuckMinutes(
                lowestDensity: low, peakDensity: peak, windowMinutes: window
            )
        )
    }
}

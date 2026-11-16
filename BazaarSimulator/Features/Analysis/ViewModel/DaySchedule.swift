import Foundation

/// Where the day starts, peaks, and ends (hours), and the sample hours the charts and tables use.
struct DaySchedule: Sendable, Equatable {
    static let defaultEventHours = TimeRange(startMinute: 10 * 60, endMinute: 18 * 60)
    static let defaultPeakMinute = 14 * 60
    static let defaultWindowMinutes = 10.0

    let startHour: Double
    let peakHour: Double
    let endHour: Double
    let windowMinutes: Double

    init(startHour: Double, peakHour: Double, endHour: Double, windowMinutes: Double = Self.defaultWindowMinutes) {
        self.startHour = startHour
        self.peakHour = peakHour
        self.endHour = endHour
        self.windowMinutes = windowMinutes
    }

    /// The schedule for a project. Anything the parameters do not give falls back to the simulator's
    /// own value: event hours of 10:00 to 18:00, and a busiest time of 14:00.
    init(parameters: EventParameters, windowMinutes: Double = Self.defaultWindowMinutes) {
        let hours = parameters.eventHours.durationMinutes > 0 ? parameters.eventHours : Self.defaultEventHours
        let peak = Self.peakMinute(in: parameters.peakPeriods, hours: hours, windowMinutes: windowMinutes)
        self.init(
            startHour: Double(hours.startMinute) / 60,
            peakHour: Double(peak) / 60,
            endHour: Double(hours.endMinute) / 60,
            windowMinutes: windowMinutes
        )
    }

    /// The first peak period that overlaps the event, else 14:00. Always inside the event hours, and
    /// moved earlier if needed so the whole window fits before closing.
    static func peakMinute(in periods: [TimeRange], hours: TimeRange, windowMinutes: Double) -> Int {
        let earliest = hours.startMinute
        let latest = max(hours.endMinute - Int(windowMinutes), earliest)
        let requested = periods
            .sorted { $0.startMinute < $1.startMinute }
            .first { $0.endMinute > earliest && $0.startMinute < hours.endMinute }?
            .startMinute ?? defaultPeakMinute
        return min(max(requested, earliest), latest)
    }

    var peakMinute: Int { Int((peakHour * 60).rounded()) }
    var peakText: String { TimeRange.format(peakMinute) }

    /// The busiest window as minutes of the day.
    var window: TimeRange {
        TimeRange(startMinute: peakMinute, endMinute: peakMinute + Int(windowMinutes))
    }

    /// Every 2 hours from the start, plus the end when it is a full hour past the last one,
    /// plus the busiest hour so the day values at that hour can equal the window values.
    var sampleHours: [Double] {
        var hours = Array(stride(from: startHour, through: endHour, by: 2))
        if let last = hours.last, endHour - last >= 1 {
            hours.append(endHour)
        }
        if !hours.contains(peakHour) {
            hours.append(peakHour)
        }
        return hours.sorted()
    }
}

import Foundation

/// Where the day starts, is busiest, and ends (hours), and the sample hours the charts and tables use.
struct DaySchedule: Sendable, Equatable {
    static let defaultEventHours = TimeRange(startMinute: 10 * 60, endMinute: 18 * 60)
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

    /// The schedule for a run. `peakMinute` is when the simulation showed the venue busiest. It is moved so the whole
    /// window fits inside the event hours, and without one the middle of the day is used. Event hours the parameters
    /// do not give fall back to 10:00 to 18:00.
    init(parameters: EventParameters, peakMinute: Int? = nil, windowMinutes: Double = Self.defaultWindowMinutes) {
        let hours = parameters.eventHours.durationMinutes > 0 ? parameters.eventHours : Self.defaultEventHours
        let latest = max(hours.endMinute - Int(windowMinutes), hours.startMinute)
        let middle = hours.startMinute + (hours.durationMinutes - Int(windowMinutes)) / 2
        let peak = min(max(peakMinute ?? middle, hours.startMinute), latest)
        self.init(
            startHour: Double(hours.startMinute) / 60,
            peakHour: Double(peak) / 60,
            endHour: Double(hours.endMinute) / 60,
            windowMinutes: windowMinutes
        )
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

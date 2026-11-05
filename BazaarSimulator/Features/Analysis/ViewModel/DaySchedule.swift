import Foundation

/// The values of one layout's busiest spot, and its door flow, at one moment of the day.
struct DayValues: Sendable, Equatable {
    var worstDensity: Double
    var heavyMinutes: Double
    var jammedSpots: Double
    var flowRate: Double
}

/// Where the day starts, peaks, and ends (hours), and the sample hours the charts and tables use.
struct DaySchedule: Sendable, Equatable {
    let startHour: Double
    let peakHour: Double
    let endHour: Double

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

    /// Straight lines from the start values up to the peak values, then down to the end values.
    /// At the peak hour the result is exactly `peak`, so tables, tiles, and charts agree.
    func values(at hour: Double, start: DayValues, peak: DayValues, end: DayValues) -> DayValues {
        if hour == peakHour { return peak }
        if hour < peakHour {
            let span = peakHour - startHour
            return Self.blend(start, peak, span > 0 ? (hour - startHour) / span : 1)
        }
        let span = endHour - peakHour
        return Self.blend(peak, end, span > 0 ? (hour - peakHour) / span : 1)
    }

    func dayPoints(start: DayValues, peak: DayValues, end: DayValues) -> [DayPoint] {
        sampleHours.map { hour in
            let value = values(at: hour, start: start, peak: peak, end: end)
            return DayPoint(
                hour: hour,
                worstDensity: value.worstDensity,
                heavyMinutes: value.heavyMinutes,
                jammedSpots: Int(value.jammedSpots.rounded()),
                flowRate: value.flowRate.rounded()
            )
        }
    }

    private static func blend(_ from: DayValues, _ to: DayValues, _ fraction: Double) -> DayValues {
        let t = min(max(fraction, 0), 1)
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return DayValues(
            worstDensity: mix(from.worstDensity, to.worstDensity),
            heavyMinutes: mix(from.heavyMinutes, to.heavyMinutes),
            jammedSpots: mix(from.jammedSpots, to.jammedSpots),
            flowRate: mix(from.flowRate, to.flowRate)
        )
    }
}

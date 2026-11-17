import Foundation

/// Finds when the venue is busiest from what the simulation measured, so the busiest time is never set by hand.
enum BusiestWindow {
    /// The start of the stretch of `windowMinutes` with the most people at the monitored spots, added over every
    /// layout so the layouts are compared in the same window. Nil when nothing was measured.
    static func startMinute(in analyses: [LayoutAnalysis], hours: TimeRange, windowMinutes: Int) -> Int? {
        guard let first = analyses.first, first.sampleIntervalSeconds > 0 else { return nil }
        let samplesPerMinute = max(60 / first.sampleIntervalSeconds, 1)
        let count = analyses.flatMap(\.spots).map { $0.peopleSamples.count }.max() ?? 0
        guard count > 0 else { return nil }

        var load = [Int](repeating: 0, count: count)
        for spot in analyses.flatMap(\.spots) {
            for (index, people) in spot.peopleSamples.enumerated() { load[index] += people }
        }

        let length = min(max(windowMinutes * samplesPerMinute, 1), count)
        var sum = load[0..<length].reduce(0, +)
        var best = sum
        var bestStart = 0
        for start in 1...max(count - length, 1) where start + length <= count {
            sum += load[start + length - 1] - load[start - 1]
            if sum > best {
                best = sum
                bestStart = start
            }
        }
        let minute = first.eventStartMinute + bestStart / samplesPerMinute
        let latest = max(hours.endMinute - windowMinutes, hours.startMinute)
        return min(max(minute, hours.startMinute), latest)
    }
}

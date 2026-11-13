import CoreGraphics
import Foundation

struct SpotOutcome: Sendable {
    let number: Int
    let name: String
    let cause: String
    let location: CGPoint
    let lowestDensity: Double
    let peakDensity: Double
    let peakVisitors: Int
    let stuckMin: Double

    /// Measured values across the busiest window, evenly spaced from its start to its end.
    /// Empty for spots written by hand, which follow a smooth curve between lowest and peak instead.
    var windowDensity: [Double] = []
    var windowPeople: [Int] = []

    var grade: SeverityGrade {
        SeverityGrade.grade(forDensity: peakDensity)
    }

    func density(at progress: Double) -> Double {
        if windowDensity.count >= 2 {
            return Self.interpolate(windowDensity, at: progress)
        }
        let clamped = min(max(progress, 0), 1)
        return lowestDensity + (peakDensity - lowestDensity) * sin(.pi * clamped)
    }

    func visitors(at progress: Double) -> Int {
        if windowPeople.count >= 2 {
            return Int(Self.interpolate(windowPeople.map(Double.init), at: progress).rounded())
        }
        let currentDensity = density(at: progress)
        let ratio = currentDensity / max(peakDensity, 0.01)
        return Int((Double(peakVisitors) * ratio).rounded())
    }

    /// A spot built from simulation measurements across the busiest window.
    static func measured(
        number: Int,
        name: String,
        cause: String,
        location: CGPoint,
        density: [Double],
        people: [Int],
        windowMinutes: Double
    ) -> SpotOutcome {
        var spot = SpotOutcome(
            number: number,
            name: name,
            cause: cause,
            location: location,
            lowestDensity: density.min() ?? 0,
            peakDensity: density.max() ?? 0,
            peakVisitors: people.max() ?? 0,
            stuckMin: stuckMinutes(of: density, windowMinutes: windowMinutes)
        )
        spot.windowDensity = density
        spot.windowPeople = people
        return spot
    }

    /// Minutes spent at or above the stuck level from the start of the window up to `progress`.
    func heavyMinutes(upTo progress: Double, windowMinutes: Double) -> Double {
        let steps = 200
        let stuck = (0..<steps).filter { step in
            let at = (Double(step) + 0.5) / Double(steps)
            return at <= progress && density(at: at) >= SeverityGrade.heavyThreshold
        }.count
        return Double(stuck) / Double(steps) * windowMinutes
    }

    static func interpolate(_ series: [Double], at progress: Double) -> Double {
        guard series.count >= 2 else { return series.first ?? 0 }
        let position = min(max(progress, 0), 1) * Double(series.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, series.count - 1)
        return series[lower] + (series[upper] - series[lower]) * (position - Double(lower))
    }

    /// Minutes in the window where the density is at or above the stuck level, from 200 evenly spaced samples.
    static func stuckMinutes(of series: [Double], windowMinutes: Double) -> Double {
        let steps = 200
        let stuck = (0..<steps).filter { step in
            interpolate(series, at: (Double(step) + 0.5) / Double(steps)) >= SeverityGrade.heavyThreshold
        }.count
        return Double(stuck) / Double(steps) * windowMinutes
    }

    static func computeStuckMinutes(
        lowestDensity: Double,
        peakDensity: Double,
        windowMinutes: Double
    ) -> Double {
        let steps = 200
        let heavyCount = (0..<steps).filter { step in
            let progress = (Double(step) + 0.5) / Double(steps)
            let density = lowestDensity + (peakDensity - lowestDensity) * sin(.pi * progress)
            return density >= SeverityGrade.heavyThreshold
        }.count
        return (Double(heavyCount) / Double(steps)) * windowMinutes
    }
}

struct DayPoint: Sendable {
    let hour: Double
    let worstDensity: Double
    let heavyMinutes: Double
    let jammedSpots: Int
    let flowRate: Double
}

struct LayoutOutcome: Sendable {
    static let defaultWindowMinutes: Double = 10.0

    let layout: LayoutID
    let name: String
    let windowMinutes: Double
    let spots: [SpotOutcome]
    let dayPoints: [DayPoint]

    var worstSpotIndex: Int {
        spots.indices.max {
            if spots[$0].peakDensity == spots[$1].peakDensity {
                return spots[$0].number > spots[$1].number
            }
            return spots[$0].peakDensity < spots[$1].peakDensity
        } ?? 0
    }

    var worstSpot: SpotOutcome {
        spots.isEmpty ? SpotOutcome(
            number: 1, name: "Aisle", cause: "",
            location: .zero, lowestDensity: 0.5, peakDensity: 1.0,
            peakVisitors: 10, stuckMin: 0
        ) : spots[worstSpotIndex]
    }

    var D: Double {
        worstSpot.peakDensity
    }

    var space: Double {
        (1.0 / max(D, 0.01) * 10).rounded() / 10
    }

    var M: Double {
        worstSpot.stuckMin
    }

    var Msum: Double {
        spots.reduce(0) { $0 + $1.stuckMin }
    }

    var C: Int {
        Self.stuckCounts(of: spots).peak
    }

    var Cavg: Double {
        Self.stuckCounts(of: spots).average
    }

    /// How many spots are stuck at once: the highest and the average over 101 evenly spaced moments.
    static func stuckCounts(of spots: [SpotOutcome]) -> (peak: Int, average: Double) {
        let counts = (0...100).map { step in
            let progress = Double(step) / 100.0
            return spots.filter { $0.density(at: progress) >= SeverityGrade.heavyThreshold }.count
        }
        return (counts.max() ?? 0, Double(counts.reduce(0, +)) / Double(counts.count))
    }

    var spotTotal: Int {
        spots.count
    }

    var flowMin: Double {
        dayPoints.map(\.flowRate).min() ?? 0
    }

    var flowMax: Double {
        dayPoints.map(\.flowRate).max() ?? 0
    }

    var flowAvg: Double {
        guard !dayPoints.isEmpty else { return 0 }
        return dayPoints.map(\.flowRate).reduce(0, +) / Double(dayPoints.count)
    }

    var swing: Double {
        guard flowAvg > 0 else { return 0 }
        return (flowMax - flowMin) / flowAvg
    }

    var isSteady: Bool {
        swing <= 0.5
    }
}

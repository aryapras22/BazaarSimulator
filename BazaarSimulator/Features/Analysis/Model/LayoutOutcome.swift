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

    var grade: SeverityGrade {
        SeverityGrade.grade(forDensity: peakDensity)
    }

    func density(at progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return lowestDensity + (peakDensity - lowestDensity) * sin(.pi * clamped)
    }

    func visitors(at progress: Double) -> Int {
        let currentDensity = density(at: progress)
        let ratio = currentDensity / max(peakDensity, 0.01)
        return Int((Double(peakVisitors) * ratio).rounded())
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
        let counts = (0...100).map { step in
            let progress = Double(step) / 100.0
            return spots.filter { $0.density(at: progress) >= SeverityGrade.heavyThreshold }.count
        }
        return counts.max() ?? 0
    }

    var Cavg: Double {
        let counts = (0...100).map { step in
            let progress = Double(step) / 100.0
            return spots.filter { $0.density(at: progress) >= SeverityGrade.heavyThreshold }.count
        }
        guard !counts.isEmpty else { return 0 }
        return Double(counts.reduce(0, +)) / Double(counts.count)
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

import Foundation
import simd

/// Represents what a simulated visitor is currently doing in the venue.
nonisolated enum VisitorState: String, Codable, CaseIterable, Hashable, Sendable {
    case walking
    case queueing
    case browsing
    case seated
    case exiting

    var label: String {
        switch self {
        case .walking: return "Walking"
        case .queueing: return "Queueing"
        case .browsing: return "Browsing"
        case .seated: return "Seated"
        case .exiting: return "Leaving"
        }
    }
}

/// One person walking the bazaar. An adult carrying a child stands for two people.
nonisolated struct SimulatedVisitor: Identifiable, Codable, Hashable, Sendable {
    var id: Int
    var position: SIMD2<Double>
    var state: VisitorState = .walking
    var peopleCount: UInt8 = 1
}

/// Summary numbers for the current simulation run.
nonisolated struct SimulationMetrics: Codable, Hashable, Sendable {
    var elapsedSeconds: Double = 0
    var arrivals: Int = 0
    var departed: Int = 0
    var peopleInside: Int = 0
    var totalVisits: Int = 0
    var queueBalks: Int = 0
    var peakDensity: Double = 0
    var meanDensity: Double = 0
    var averageStaySeconds: Double = 0
}

/// A 1m x 1m floor cell used to visualize local crowd density (people/m²) in the venue.
nonisolated struct DensityCell: Identifiable, Codable, Hashable, Sendable {
    var id: Int
    var center: SIMD2<Double>
    var peoplePerSquareMetre: Double
}

/// Pure helper that keeps the 4 visitor type sliders totaling 100% at all times while respecting locks.
enum VisitorShareBalancer {
    /// Adjusts `shares` when slider `changedIndex` moves to `newValue`.
    /// - Total always remains 100%.
    /// - Locked sliders never change.
    /// - Reducing a slider incrementally adds the freed percentage across unlocked sliders.
    /// - Increasing a slider scales down unlocked sliders proportionally.
    static func adjust(
        shares: [Double],
        locked: [Bool],
        changedIndex: Int,
        newValue: Double
    ) -> [Double] {
        guard shares.count == 4, locked.count == 4,
               changedIndex >= 0, changedIndex < 4,
              !locked[changedIndex] else {
            return shares
        }

        var result = shares
        let lockedOthersSum = (0..<4)
            .filter { $0 != changedIndex && locked[$0] }
            .reduce(0.0) { $0 + result[$1] }

        let unlockedOtherIndices = (0..<4).filter { $0 != changedIndex && !locked[$0] }
        let maxAllowed = max(0.0, 100.0 - lockedOthersSum)

        // If all other sliders are locked, this slider must fill the remaining space to stay at 100%
        if unlockedOtherIndices.isEmpty {
            result[changedIndex] = maxAllowed
            return result
        }

        let clampedNew = min(max(0.0, newValue.rounded()), maxAllowed)
        result[changedIndex] = clampedNew

        let unlockedOthersSum = unlockedOtherIndices.reduce(0.0) { $0 + result[$1] }
        let availableForUnlocked = max(0.0, 100.0 - lockedOthersSum - clampedNew)

        if availableForUnlocked >= unlockedOthersSum {
            // Slider was reduced: incrementally add the freed share across all unlocked sliders
            let surplus = availableForUnlocked - unlockedOthersSum
            let count = Double(unlockedOtherIndices.count)
            var assigned = 0.0
            for (offset, idx) in unlockedOtherIndices.enumerated() {
                if offset == unlockedOtherIndices.count - 1 {
                    result[idx] = max(0.0, (availableForUnlocked - assigned).rounded())
                } else {
                    let updated = (result[idx] + surplus / count).rounded()
                    result[idx] = updated
                    assigned += updated
                }
            }
        } else if unlockedOthersSum > 0 {
            // Slider was increased: scale down unlocked sliders proportionally
            let scale = availableForUnlocked / unlockedOthersSum
            var assigned = 0.0
            for (offset, idx) in unlockedOtherIndices.enumerated() {
                if offset == unlockedOtherIndices.count - 1 {
                    result[idx] = max(0.0, (availableForUnlocked - assigned).rounded())
                } else {
                    let scaled = (result[idx] * scale).rounded()
                    result[idx] = scaled
                    assigned += scaled
                }
            }
        } else {
            for idx in unlockedOtherIndices {
                result[idx] = 0.0
            }
        }

        return result
    }
}

/// User-configured event parameters from the Parameter modal.
struct EventParameters: Codable, Hashable, Sendable {
    var totalVisitors: Int = 2000
    var startMinutes: Int = 10 * 60
    var endMinutes: Int = 21 * 60
    var bazaarType: String = "Family & Kids"

    var socializerPercent: Double = 21
    var familyMemberPercent: Double = 46
    var strollerPercent: Double = 33
    var purposeBuyerPercent: Double = 0

    var durationMinutes: Int {
        if endMinutes > startMinutes {
            return endMinutes - startMinutes
        }
        return max(60, (24 * 60 - startMinutes) + endMinutes)
    }

    /// Converts the user's modal parameters into engine settings.
    func toSimulationSettings() -> SimulationSettings {
        let totalMins = max(15, durationMinutes)
        let intervalsOf15Min = Double(totalMins) / 15.0
        let cleanTotal = max(1, totalVisitors)
        let baseRate = Double(cleanTotal) / max(1.0, intervalsOf15Min)

        return SimulationSettings(
            totalVisitors: cleanTotal,
            arrivalsPer15Min: max(0.2, baseRate),
            durationMinutes: totalMins,
            startMinutesFromMidnight: startMinutes,
            simulationSpeed: 5.0,
            maxQueueLength: CrowdParameters.defaultMaxQueueLength,
            maxQueueWaitSeconds: CrowdParameters.defaultMaxQueueWaitSeconds,
            randomSeed: 7,
            socializerWeight: socializerPercent,
            familyWeight: familyMemberPercent,
            strollerWeight: strollerPercent,
            buyerWeight: purposeBuyerPercent
        )
    }
}

/// Basic settings that control how the simulation engine runs.
nonisolated struct SimulationSettings: Codable, Hashable, Sendable {
    var totalVisitors: Int = 600
    var arrivalsPer15Min: Double = 180.0
    var durationMinutes: Int = 660
    var startMinutesFromMidnight: Int = 600
    var simulationSpeed: Double = 5.0
    var maxQueueLength: Int = CrowdParameters.defaultMaxQueueLength
    var maxQueueWaitSeconds: Double = CrowdParameters.defaultMaxQueueWaitSeconds
    var randomSeed: UInt64 = 7

    var socializerWeight: Double = 25
    var familyWeight: Double = 25
    var strollerWeight: Double = 25
    var buyerWeight: Double = 25
}

/// A recorded snapshot of the simulation at a specific timestamp for footage playback.
nonisolated struct SimulationFrame: Codable, Hashable, Sendable {
    var elapsedSeconds: Double
    var visitors: [SimulatedVisitor]
    var densityCells: [DensityCell]
    var metrics: SimulationMetrics
}

/// Saved result of running a simulation on a layout, including heatmap data and recorded footage.
nonisolated struct SimulationResult: Codable, Hashable, Sendable {
    var layoutID: UUID
    var layoutName: String
    var durationSeconds: Double = 39_600
    var startMinutesFromMidnight: Int = 600
    var metrics: SimulationMetrics
    var densityCells: [DensityCell]
    var frames: [SimulationFrame]
}

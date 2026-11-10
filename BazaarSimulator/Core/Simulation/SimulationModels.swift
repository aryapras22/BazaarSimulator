import Foundation
import simd

/// Represents what a simulated visitor is currently doing in the venue.
enum VisitorState: String, Codable, CaseIterable, Hashable, Sendable {
    case walking
    case queueing
    case browsing
    case exiting

    var label: String {
        switch self {
        case .walking: return "Walking"
        case .queueing: return "Queueing"
        case .browsing: return "Browsing"
        case .exiting: return "Leaving"
        }
    }
}

/// Represents a single visitor (or small group) moving around the bazaar.
struct SimulatedVisitor: Identifiable, Codable, Hashable, Sendable {
    var id: Int
    var persona: String
    var position: SIMD2<Double>
    var heading: Double = 0
    var state: VisitorState = .walking
    var partySize: Int = 1
    var targetBoothID: UUID?
    var visitedBoothIDs: [UUID] = []
    var plannedStops: Int = 2
    var speed: Double = 1.0
    var timeInState: Double = 0
    var stateDuration: Double = 20.0
    var totalStaySeconds: Double = 0
    var path: [SIMD2<Double>] = []
}

/// Summary numbers for the current simulation run.
struct SimulationMetrics: Codable, Hashable, Sendable {
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
struct DensityCell: Identifiable, Codable, Hashable, Sendable {
    var id: Int
    var center: SIMD2<Double>
    var peoplePerSquareMetre: Double
}

/// Pure helper that keeps the 4 visitor type sliders within the 100% cap while respecting locks.
enum VisitorShareBalancer {
    /// Adjusts `shares` when slider `changedIndex` moves to `newValue`.
    /// - Locked sliders never change.
    /// - Other unlocked sliders only move if `newValue` forces the total to collide with 100%.
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
        let unlockedOthersSum = unlockedOtherIndices.reduce(0.0) { $0 + result[$1] }

        // If all other sliders are locked, this slider cannot push past the remaining space
        let maxAllowed: Double
        if unlockedOtherIndices.isEmpty {
            maxAllowed = max(0.0, 100.0 - lockedOthersSum)
        } else {
            maxAllowed = max(0.0, 100.0 - lockedOthersSum)
        }

        let clampedNew = min(max(0.0, newValue.rounded()), maxAllowed)
        result[changedIndex] = clampedNew

        let proposedTotal = lockedOthersSum + clampedNew + unlockedOthersSum
        // Only move other unlocked sliders when a collision with the 100% ceiling occurs
        guard proposedTotal > 100.0, !unlockedOtherIndices.isEmpty else {
            return result
        }

        let availableForUnlocked = max(0.0, 100.0 - lockedOthersSum - clampedNew)
        if unlockedOthersSum > 0 {
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
    var isPeakHoursEnabled: Bool = true
    var peakPeriods: [String] = [
        "08:00 - 10:00", "10:00 - 12:00", "12:00 - 14:00",
        "14:00 - 16:00", "16:00 - 18:00", "18:00 - 20:00"
    ]
    var selectedPeakPeriods: Set<String> = ["12:00 - 14:00", "18:00 - 20:00"]
    var bazaarType: String = "Family & Kids"

    var socializerPercent: Double = 21
    var familyMemberPercent: Double = 46
    var strollerPercent: Double = 33
    var purposeBuyerPercent: Double = 0

    var maxGroupSize: Int = 5

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
        let peakBoost = isPeakHoursEnabled && !selectedPeakPeriods.isEmpty ? 1.35 : 1.0

        return SimulationSettings(
            totalVisitors: cleanTotal,
            arrivalsPer15Min: max(0.2, baseRate * peakBoost),
            durationMinutes: totalMins,
            startMinutesFromMidnight: startMinutes,
            simulationSpeed: 5.0,
            maxQueueLength: 6,
            maxQueueWaitSeconds: 120.0,
            randomSeed: 7,
            socializerWeight: socializerPercent,
            familyWeight: familyMemberPercent,
            strollerWeight: strollerPercent,
            buyerWeight: purposeBuyerPercent,
            maxGroupSize: max(1, maxGroupSize)
        )
    }
}

/// Basic settings that control how the simulation engine runs.
struct SimulationSettings: Codable, Hashable, Sendable {
    var totalVisitors: Int = 600
    var arrivalsPer15Min: Double = 180.0
    var durationMinutes: Int = 660
    var startMinutesFromMidnight: Int = 600
    var simulationSpeed: Double = 5.0
    var maxQueueLength: Int = 6
    var maxQueueWaitSeconds: Double = 120.0
    var randomSeed: UInt64 = 7

    var socializerWeight: Double = 25
    var familyWeight: Double = 25
    var strollerWeight: Double = 25
    var buyerWeight: Double = 25
    var maxGroupSize: Int = 4
}

/// A recorded snapshot of the simulation at a specific timestamp for footage playback.
struct SimulationFrame: Codable, Hashable, Sendable {
    var elapsedSeconds: Double
    var visitors: [SimulatedVisitor]
    var densityCells: [DensityCell]
    var metrics: SimulationMetrics
}

/// Saved result of running a simulation on a layout, including heatmap data and recorded footage.
struct SimulationResult: Codable, Hashable, Sendable {
    var layoutID: UUID
    var layoutName: String
    var durationSeconds: Double = 39_600
    var startMinutesFromMidnight: Int = 600
    var metrics: SimulationMetrics
    var densityCells: [DensityCell]
    var frames: [SimulationFrame]
}

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

/// A 2m x 2m floor cell used to visualize crowd density in the venue.
struct DensityCell: Identifiable, Codable, Hashable, Sendable {
    var id: Int
    var center: SIMD2<Double>
    var peoplePerSquareMetre: Double
}

/// User-configured event parameters from the Parameter modal.
struct EventParameters: Codable, Hashable, Sendable {
    var totalVisitors: Int = 2000
    var startHour: Int = 10
    var endHour: Int = 21
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

    /// Converts the user's modal parameters into engine settings.
    func toSimulationSettings() -> SimulationSettings {
        let hours = max(1, endHour - startHour)
        let intervalsOf15Min = Double(hours * 4)
        let baseRate = Double(max(50, totalVisitors)) / max(1.0, intervalsOf15Min)
        let peakBoost = isPeakHoursEnabled && !selectedPeakPeriods.isEmpty ? 1.4 : 1.0

        return SimulationSettings(
            totalVisitors: max(20, totalVisitors),
            arrivalsPer15Min: max(30.0, baseRate * peakBoost),
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
    var metrics: SimulationMetrics
    var densityCells: [DensityCell]
    var frames: [SimulationFrame]
}

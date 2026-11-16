import Foundation
import simd

/// Represents a crowded hotspot location found during the simulation.
struct HotspotFinding: Identifiable, Hashable, Sendable {
    var id: Int
    var point: SIMD2<Double>
    var density: Double
    var grade: String
    var label: String
}

/// Simple helper that grades crowd density and summarizes hotspots for the Analysis screen.
enum SimulationAnalysis {
    static let gradeThresholds: [(grade: String, maxDensity: Double)] = [
        ("A", 0.08),
        ("B", 0.27),
        ("C", 0.45),
        ("D", 0.72),
        ("E", 1.80),
        ("F", .infinity)
    ]

    /// Returns a Fruin crowd density grade from A (free flow) to F (critical crowding).
    static func grade(for density: Double) -> String {
        for item in gradeThresholds where density <= item.maxDensity {
            return item.grade
        }
        return "F"
    }

    /// Finds the top crowded hotspot locations that are at least `separation` metres apart.
    static func bottlenecks(
        from cells: [DensityCell],
        limit: Int = 5,
        separation: Double = 3.5
    ) -> [HotspotFinding] {
        let sorted = cells.sorted { $0.peoplePerSquareMetre > $1.peoplePerSquareMetre }
        var chosen: [DensityCell] = []

        for cell in sorted {
            guard cell.peoplePerSquareMetre >= 0.27 else { break }
            let isFarEnough = chosen.allSatisfy { existing in
                simd_distance(existing.center, cell.center) >= separation
            }
            if isFarEnough {
                chosen.append(cell)
                if chosen.count >= limit { break }
            }
        }

        return chosen.enumerated().map { index, cell in
            HotspotFinding(
                id: index,
                point: cell.center,
                density: cell.peoplePerSquareMetre,
                grade: grade(for: cell.peoplePerSquareMetre),
                label: "(\(Int(cell.center.x))m, \(Int(cell.center.y))m)"
            )
        }
    }

    /// Generates plain-language organizer advice from the simulation metrics and hotspots.
    static func organizerAdvice(metrics: SimulationMetrics, findings: [HotspotFinding]) -> String {
        if metrics.peakDensity >= 0.72 {
            return "High local crowding (Grade D or worse) was detected. "
                + "Consider widening aisles near the red hotspot areas, spacing out popular booths, "
                + "or enabling additional exit doors."
        }
        if metrics.queueBalks > 0 {
            return "Some visitors skipped booths because queues got too long. "
                + "Spreading popular categories across the hall can help balance visitor flow."
        }
        if !findings.isEmpty {
            return "Moderate crowd build-up was observed in a few aisles. "
                + "Review the highlighted yellow/orange cells on the heatmap "
                + "or inspect the 3D simulation footage."
        }
        return "Visitor flow looks smooth with low crowding across the venue. "
            + "You can inspect the 3D simulation footage or test higher visitor numbers in Parameters."
    }
}

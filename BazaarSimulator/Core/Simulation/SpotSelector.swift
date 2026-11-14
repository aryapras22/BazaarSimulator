import Foundation
import simd

/// Picks the monitored spots after a run: the most crowded blocks of floor in the busiest window.
enum SpotSelector {
    static let maxSpots = 4
    static let minimumSeparationM = 8.0
    static let minimumAreaM2 = 6.0

    struct Candidate {
        let block: Int
        let areaM2: Double
    }

    /// `peaks` and `dayPeaks` are people per m² for each block: highest in the window, highest all day.
    static func select(candidates: [Candidate], peaks: [Double], dayPeaks: [Double], centers: [SIMD2<Double>]) -> [Int] {
        let ranked = candidates.sorted { first, second in
            if peaks[first.block] != peaks[second.block] { return peaks[first.block] > peaks[second.block] }
            if dayPeaks[first.block] != dayPeaks[second.block] { return dayPeaks[first.block] > dayPeaks[second.block] }
            return first.block < second.block
        }
        var chosen: [Int] = []
        for candidate in ranked {
            guard chosen.count < maxSpots else { break }
            let isFarEnough = chosen.allSatisfy {
                simd_distance(centers[$0], centers[candidate.block]) >= minimumSeparationM
            }
            if isFarEnough { chosen.append(candidate.block) }
        }
        return chosen
    }

    /// A short name from what is nearby: a door, the lobby, a zone strip, or just "Aisle".
    static func name(at point: SIMD2<Double>, in layout: Layout, grid: NavigationGrid) -> String {
        let nearestDoor = grid.doors
            .map { (door: $0, distance: simd_distance($0.center, point)) }
            .filter { $0.distance <= 6 }
            .min { $0.distance < $1.distance }
        if let nearestDoor { return "Near \(nearestDoor.door.label)" }
        if LayoutGeometry.polygonContains(layout.lobby, point: point) { return "Lobby" }
        if let zone = layout.zones.first(where: { point.x >= $0.minX && point.x <= $0.maxX }) {
            return "Zone \(zone.label) Aisle"
        }
        return "Aisle"
    }

    /// Makes repeated names unique: the second "Aisle" becomes "Aisle 2".
    static func uniqueNames(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return names.map { name in
            seen[name, default: 0] += 1
            return seen[name] == 1 ? name : "\(name) \(seen[name]!)"
        }
    }
}

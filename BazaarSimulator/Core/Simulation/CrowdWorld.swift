import Foundation
import simd

/// A rotated rectangle on the floor, measured from outside.
nonisolated struct CrowdFootprint {
    let center: SIMD2<Double>
    let halfSize: SIMD2<Double>
    private let cosine: Double
    private let sine: Double

    @MainActor
    init(_ placement: Placement, margin: Double = 0) {
        center = placement.center
        halfSize = placement.sizeM / 2 + SIMD2(repeating: margin)
        cosine = cos(placement.rotationRadians)
        sine = sin(placement.rotationRadians)
    }

    var boundingRadius: Double { simd_length(halfSize) }

    func nearestPoint(to point: SIMD2<Double>) -> SIMD2<Double> {
        let delta = point - center
        let local = SIMD2(delta.x * cosine + delta.y * sine, -delta.x * sine + delta.y * cosine)
        let clamped = simd_clamp(local, -halfSize, halfSize)
        return center + SIMD2(clamped.x * cosine - clamped.y * sine, clamped.x * sine + clamped.y * cosine)
    }

    func distance(to point: SIMD2<Double>) -> Double {
        simd_distance(point, nearestPoint(to: point))
    }
}

nonisolated struct CrowdBooth {
    let id: UUID
    let isFood: Bool
    /// A stage, photobooth, competition or display: visitors stop there on top of their booth budget.
    let isEntertainment: Bool
    let footprint: CrowdFootprint
    let pull: Double
    let capacity: Int
    var gateCosts: [Float] = []

    func isReachable(fromGate gate: Int) -> Bool {
        gateCosts[gate] < CrowdWorld.reachableCostLimit
    }
}

/// A place one party sits: a table, or a few chairs side by side in a seating block.
nonisolated struct CrowdTable {
    let footprint: CrowdFootprint
    /// Where each member sits, in order.
    let seats: [SIMD2<Double>]
    var isReachable = false
}

/// A cell of a one-way door, which cannot be entered from its wrong side.
nonisolated struct CrowdDoorRule {
    let inward: SIMD2<Double>
    let forbidsWalkingIn: Bool
}

/// The floor grid as plain values, so the parallel steering pass can read it without touching shared objects.
nonisolated struct CrowdWallMap {
    let width: Double
    let height: Double
    let cols: Int
    let rows: Int
    var floor: [Bool]
    var wallDistances: [Float]

    init(width: Double, height: Double, cols: Int, rows: Int) {
        self.width = width
        self.height = height
        self.cols = cols
        self.rows = rows
        floor = Array(repeating: false, count: cols * rows)
        wallDistances = Array(repeating: 0, count: cols * rows)
    }

    func cell(at point: SIMD2<Double>) -> Int {
        let col = max(0, min(cols - 1, Int(Foundation.floor(point.x / CrowdWorld.cellSize))))
        let row = max(0, min(rows - 1, Int(Foundation.floor(point.y / CrowdWorld.cellSize))))
        return row * cols + col
    }

    func isFree(_ point: SIMD2<Double>) -> Bool {
        guard point.x >= 0, point.y >= 0, point.x < width, point.y < height else { return false }
        return floor[cell(at: point)]
    }

    func hasLineOfSight(from start: SIMD2<Double>, to end: SIMD2<Double>) -> Bool {
        let samples = Int(ceil(simd_distance(start, end) / 0.4))
        guard samples >= 2 else { return true }
        return (1..<samples).allSatisfy { isFree(start + (end - start) * (Double($0) / Double(samples))) }
    }

    /// Distance to the nearest wall, positive on free floor and negative inside obstacles.
    func wallDistance(at point: SIMD2<Double>) -> Double {
        let gridX = point.x / CrowdWorld.cellSize - 0.5
        let gridY = point.y / CrowdWorld.cellSize - 0.5
        let col = max(0, min(cols - 2, Int(Foundation.floor(gridX))))
        let row = max(0, min(rows - 2, Int(Foundation.floor(gridY))))
        let fractionX = gridX - Double(col)
        let fractionY = gridY - Double(row)
        let base = row * cols + col
        let lower = simd_mix(Double(wallDistances[base]), Double(wallDistances[base + 1]), fractionX)
        let upper = simd_mix(Double(wallDistances[base + cols]), Double(wallDistances[base + cols + 1]), fractionX)
        return simd_mix(lower, upper, fractionY)
    }

    func wallGradient(at point: SIMD2<Double>) -> SIMD2<Double> {
        let offset = 0.12
        let stepX = SIMD2(offset, 0.0)
        let stepY = SIMD2(0.0, offset)
        return SIMD2(
            (wallDistance(at: point + stepX) - wallDistance(at: point - stepX)) / (2 * offset),
            (wallDistance(at: point + stepY) - wallDistance(at: point - stepY)) / (2 * offset)
        )
    }
}

/// The floor as the crowd sees it: walkable cells, distance to walls, doors, booths, tables and routes.
nonisolated final class CrowdWorld: @unchecked Sendable {
    static let cellSize = 0.25
    /// One step through a gap too narrow to walk costs 750, so anything cheaper is a real route.
    static let reachableCostLimit: Float = 700

    let layout: Layout
    let width: Double
    let height: Double
    let cols: Int
    let rows: Int
    let cellCount: Int

    var walls: CrowdWallMap
    var inboundBlocked: [Bool]
    var outboundBlocked: [Bool]
    var cornerWeights: [Float]
    var doorRules: [Int: CrowdDoorRule] = [:]
    var booths: [CrowdBooth] = []
    var tables: [CrowdTable] = []
    var gates: [SIMD2<Double>]
    var gateWidths: [Double] = []
    var exits: [SIMD2<Double>]
    var fieldCache: [CrowdFlowTarget: CrowdFlowField] = [:]

    @MainActor
    init(layout: Layout, legend: Legend = Legend()) {
        self.layout = layout
        width = max(1.0, layout.sizeM.x)
        height = max(1.0, layout.sizeM.y)
        cols = max(2, Int(ceil(width / Self.cellSize)))
        rows = max(2, Int(ceil(height / Self.cellSize)))
        cellCount = cols * rows
        walls = CrowdWallMap(width: width, height: height, cols: cols, rows: rows)
        inboundBlocked = Array(repeating: false, count: cellCount)
        outboundBlocked = Array(repeating: false, count: cellCount)
        cornerWeights = Array(repeating: 0, count: cellCount)
        gates = Self.resolveEntrances(in: layout)
        exits = Self.resolveExits(in: layout)

        buildBoothsAndTables(legend: legend)
        buildFloor()
        gates = gates.map(nearestFreePoint)
        exits = exits.map(nearestFreePoint)
        buildWallDistances()
        buildOneWayDoors()
        buildCornerSlowdown()
        buildGateWidths()
        measureRoutesFromGates()
    }

    func cellCenter(_ cell: Int) -> SIMD2<Double> {
        SIMD2((Double(cell % cols) + 0.5) * Self.cellSize, (Double(cell / cols) + 0.5) * Self.cellSize)
    }

    func cell(at point: SIMD2<Double>) -> Int { walls.cell(at: point) }

    func isFree(_ point: SIMD2<Double>) -> Bool { walls.isFree(point) }

    func hasLineOfSight(from start: SIMD2<Double>, to end: SIMD2<Double>) -> Bool {
        walls.hasLineOfSight(from: start, to: end)
    }

    func nearestFreePoint(to point: SIMD2<Double>) -> SIMD2<Double> {
        let origin = cell(at: point)
        if walls.floor[origin] { return point }
        let originCol = origin % cols
        let originRow = origin / cols
        for radius in 1...56 {
            for row in max(0, originRow - radius)...min(rows - 1, originRow + radius) {
                for col in max(0, originCol - radius)...min(cols - 1, originCol + radius)
                where walls.floor[row * cols + col] {
                    return cellCenter(row * cols + col)
                }
            }
        }
        return point
    }

    func wallDistance(at point: SIMD2<Double>) -> Double { walls.wallDistance(at: point) }

    /// The share of normal walking speed left at this spot, lower near inner corners of the hall.
    func cornerSpeedFactor(at point: SIMD2<Double>) -> Double {
        1 - CrowdParameters.cornerSlowdown * Double(cornerWeights[cell(at: point)])
    }

    func cells(within radius: Double, of center: SIMD2<Double>) -> [Int] {
        cellsInBox(around: center, reach: radius).filter {
            walls.floor[$0] && simd_distance(cellCenter($0), center) <= radius
        }
    }

    func ringCells(around footprint: CrowdFootprint, from inner: Double, to outer: Double) -> [Int] {
        cellsInBox(around: footprint.center, reach: footprint.boundingRadius + outer).filter {
            guard walls.floor[$0] else { return false }
            let distance = footprint.distance(to: cellCenter($0))
            return distance > inner && distance <= outer
        }
    }

    func cellsInBox(around center: SIMD2<Double>, reach: Double) -> [Int] {
        let minCol = max(0, Int(Foundation.floor((center.x - reach) / Self.cellSize)))
        let maxCol = min(cols - 1, Int(Foundation.floor((center.x + reach) / Self.cellSize)))
        let minRow = max(0, Int(Foundation.floor((center.y - reach) / Self.cellSize)))
        let maxRow = min(rows - 1, Int(Foundation.floor((center.y + reach) / Self.cellSize)))
        guard minCol <= maxCol, minRow <= maxRow else { return [] }

        var result: [Int] = []
        for row in minRow...maxRow {
            for col in minCol...maxCol { result.append(row * cols + col) }
        }
        return result
    }
}

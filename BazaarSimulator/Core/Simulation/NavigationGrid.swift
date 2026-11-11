import Foundation
import simd

/// A simple 2D grid that knows which parts of the floor visitors can walk on
/// and finds walking paths around booths and walls.
struct NavigationGrid: Sendable {
    let cellSize: Double = 0.5
    let cols: Int
    let rows: Int
    let width: Double
    let height: Double

    private var walkable: [Bool]
    private var distanceCache: [Int: [Int]] = [:]

    let entrancePoints: [SIMD2<Double>]
    let exitPoints: [SIMD2<Double>]

    init(layout: Layout) {
        self.width = max(1.0, layout.sizeM.x)
        self.height = max(1.0, layout.sizeM.y)
        self.cols = max(1, Int(ceil(width / cellSize)))
        self.rows = max(1, Int(ceil(height / cellSize)))

        var grid = Array(repeating: false, count: cols * rows)
        let obstacles = layout.objects.filter { $0.kind.blocksWalking }
        let activeDoors = layout.objects.filter {
            $0.kind == .door && $0.doorFlow?.direction != .disabled
        }

        // 1. Mark floor cells as walkable if they are not inside an obstacle
        for row in 0..<rows {
            for col in 0..<cols {
                let point = SIMD2<Double>(
                    (Double(col) + 0.5) * cellSize,
                    (Double(row) + 0.5) * cellSize
                )
                let onFloor = Self.isPointOnFloor(point, in: layout)
                let blocked = obstacles.contains {
                    LayoutGeometry.contains($0.placement, point: point, tolerance: 0.1)
                }
                grid[row * cols + col] = onFloor && !blocked
            }
        }

        // 2. Carve open corridors through active doors so visitors can cross between hall and lobby
        for door in activeDoors {
            Self.carveDoor(door, into: &grid, cols: cols, rows: rows, cellSize: cellSize)
        }

        self.walkable = grid
        self.entrancePoints = Self.resolveEntrances(in: layout)
        self.exitPoints = Self.resolveExits(in: layout)
    }

    /// Checks if a position in metres is on a walkable grid cell.
    func isWalkable(_ point: SIMD2<Double>) -> Bool {
        let col = Int(floor(point.x / cellSize))
        let row = Int(floor(point.y / cellSize))
        guard col >= 0, row >= 0, col < cols, row < rows else { return false }
        return walkable[row * cols + col]
    }

    /// Picks a walkable spot right in front of a booth where a visitor can stand and browse.
    func boothApproachPoint(for booth: LayoutObject) -> SIMD2<Double> {
        let center = booth.placement.center
        let halfW = booth.placement.sizeM.x / 2.0 + 0.6
        let halfH = booth.placement.sizeM.y / 2.0 + 0.6

        let candidates = [
            SIMD2<Double>(center.x, center.y - halfH),
            SIMD2<Double>(center.x, center.y + halfH),
            SIMD2<Double>(center.x - halfW, center.y),
            SIMD2<Double>(center.x + halfW, center.y)
        ]

        if let valid = candidates.first(where: { isWalkable($0) }) {
            return valid
        }
        return nearestWalkablePoint(to: center)
    }

    func nearestWalkablePoint(to point: SIMD2<Double>) -> SIMD2<Double> {
        nearestWalkableIndex(to: point).map(cellCenter(for:)) ?? point
    }

    /// Finds the waypoints of the shortest route from `start` to `goal`, using a cached distance field per goal.
    /// Returns an empty list when no walking route exists.
    mutating func findPath(from start: SIMD2<Double>, to goal: SIMD2<Double>) -> [SIMD2<Double>] {
        guard let startIndex = nearestWalkableIndex(to: start),
              let goalIndex = nearestWalkableIndex(to: goal) else {
            return []
        }

        let distances = distanceField(for: goalIndex)
        guard distances[startIndex] >= 0 else {
            return []
        }

        var path: [SIMD2<Double>] = []
        var current = startIndex
        var visited = Set<Int>([current])
        let maxSteps = cols * rows

        while current != goalIndex && path.count < maxSteps {
            guard let next = bestNeighbor(of: current, using: distances),
                  visited.insert(next).inserted else {
                break
            }
            current = next
            path.append(cellCenter(for: current))
        }

        path.append(isWalkable(goal) ? goal : cellCenter(for: goalIndex))
        return simplifyWaypoints(path)
    }
}

// MARK: - Private Grid Helpers

extension NavigationGrid {
    private static func isPointOnFloor(_ point: SIMD2<Double>, in layout: Layout) -> Bool {
        let hasPolygons = layout.hall.count >= 3 || layout.lobby.count >= 3
        if !hasPolygons {
            return point.x >= 0.5 && point.x <= layout.sizeM.x - 0.5
                && point.y >= 0.5 && point.y <= layout.sizeM.y - 0.5
        }
        return LayoutGeometry.polygonContains(layout.hall, point: point)
            || LayoutGeometry.polygonContains(layout.lobby, point: point)
    }

    private static func carveDoor(
        _ door: LayoutObject,
        into grid: inout [Bool],
        cols: Int,
        rows: Int,
        cellSize: Double
    ) {
        var expanded = door.placement
        expanded.sizeM.x = max(expanded.sizeM.x, 1.4)
        expanded.sizeM.y = max(expanded.sizeM.y, 1.6)

        for row in 0..<rows {
            for col in 0..<cols {
                let point = SIMD2<Double>(
                    (Double(col) + 0.5) * cellSize,
                    (Double(row) + 0.5) * cellSize
                )
                if LayoutGeometry.contains(expanded, point: point, tolerance: 0.25) {
                    grid[row * cols + col] = true
                }
            }
        }
    }

    private static func resolveEntrances(in layout: Layout) -> [SIMD2<Double>] {
        let spawnMarkers = layout.markers.filter { $0.kind == .spawn }.map(\.position)
        if !spawnMarkers.isEmpty { return spawnMarkers }

        let entryDoors = layout.objects.filter {
            $0.kind == .door && ($0.doorFlow?.direction.allowsEntry ?? true)
        }
        if !entryDoors.isEmpty { return entryDoors.map(\.placement.center) }

        return [SIMD2<Double>(layout.sizeM.x / 2.0, max(1.0, layout.sizeM.y - 2.0))]
    }

    private static func resolveExits(in layout: Layout) -> [SIMD2<Double>] {
        let exitMarkers = layout.markers.filter { $0.kind == .exit }.map(\.position)
        if !exitMarkers.isEmpty { return exitMarkers }

        let exitDoors = layout.objects.filter {
            $0.kind == .door && ($0.doorFlow?.direction.allowsExit ?? true)
        }
        if !exitDoors.isEmpty { return exitDoors.map(\.placement.center) }

        return resolveEntrances(in: layout)
    }

    private func cellCenter(for index: Int) -> SIMD2<Double> {
        let col = index % cols
        let row = index / cols
        return SIMD2<Double>(
            (Double(col) + 0.5) * cellSize,
            (Double(row) + 0.5) * cellSize
        )
    }

    private func nearestWalkableIndex(to point: SIMD2<Double>) -> Int? {
        let startCol = min(cols - 1, max(0, Int(point.x / cellSize)))
        let startRow = min(rows - 1, max(0, Int(point.y / cellSize)))
        let startIndex = startRow * cols + startCol

        if walkable[startIndex] { return startIndex }

        for radius in 1...14 {
            let minRow = max(0, startRow - radius)
            let maxRow = min(rows - 1, startRow + radius)
            let minCol = max(0, startCol - radius)
            let maxCol = min(cols - 1, startCol + radius)

            for row in minRow...maxRow {
                for col in minCol...maxCol where walkable[row * cols + col] {
                    return row * cols + col
                }
            }
        }
        return nil
    }

    private mutating func distanceField(for goalIndex: Int) -> [Int] {
        if let cached = distanceCache[goalIndex] {
            return cached
        }

        var distances = Array(repeating: -1, count: cols * rows)
        var frontier = CellHeap()
        distances[goalIndex] = 0
        frontier.push(cost: 0, cell: goalIndex)

        while let (cost, current) = frontier.popMin() {
            // A cell is pushed again each time a cheaper route to it appears, so older entries are stale.
            guard cost == distances[current] else { continue }

            for step in Self.neighborSteps {
                guard let next = neighbor(of: current, by: step) else { continue }
                let nextCost = cost + step.cost
                if distances[next] < 0 || nextCost < distances[next] {
                    distances[next] = nextCost
                    frontier.push(cost: nextCost, cell: next)
                }
            }
        }

        distanceCache[goalIndex] = distances
        return distances
    }

    private func bestNeighbor(of index: Int, using distances: [Int]) -> Int? {
        var bestIndex: Int?
        var bestRouteCost = Int.max

        for step in Self.neighborSteps {
            guard let next = neighbor(of: index, by: step), distances[next] >= 0 else { continue }
            let routeCost = step.cost + distances[next]
            if routeCost < bestRouteCost {
                bestRouteCost = routeCost
                bestIndex = next
            }
        }
        return bestIndex
    }

    private static let neighborSteps: [GridStep] = [
        GridStep(dCol: 1, dRow: 0, cost: 10), GridStep(dCol: -1, dRow: 0, cost: 10),
        GridStep(dCol: 0, dRow: 1, cost: 10), GridStep(dCol: 0, dRow: -1, cost: 10),
        GridStep(dCol: 1, dRow: 1, cost: 14), GridStep(dCol: 1, dRow: -1, cost: 14),
        GridStep(dCol: -1, dRow: 1, cost: 14), GridStep(dCol: -1, dRow: -1, cost: 14)
    ]

    private func neighbor(of index: Int, by step: GridStep) -> Int? {
        let col = index % cols
        let row = index / cols
        let nextCol = col + step.dCol
        let nextRow = row + step.dRow
        guard nextCol >= 0, nextRow >= 0, nextCol < cols, nextRow < rows else { return nil }
        let next = nextRow * cols + nextCol

        // A diagonal also needs both side cells open, or it passes through obstacles that touch at a corner.
        guard walkable[next], walkable[row * cols + nextCol], walkable[nextRow * cols + col] else { return nil }
        return next
    }

    private func simplifyWaypoints(_ points: [SIMD2<Double>]) -> [SIMD2<Double>] {
        guard points.count > 2 else { return points }
        var simplified: [SIMD2<Double>] = [points[0]]
        var lastDirection = simd_normalize(points[1] - points[0])

        for index in 1..<(points.count - 1) {
            let delta = points[index + 1] - points[index]
            let length = simd_length(delta)
            guard length > 0.001 else { continue }
            let direction = delta / length
            if simd_distance(direction, lastDirection) > 0.1 {
                simplified.append(points[index])
                lastDirection = direction
            }
        }

        if let last = points.last {
            simplified.append(last)
        }
        return simplified
    }
}

private struct GridStep {
    let dCol: Int
    let dRow: Int
    let cost: Int
}

/// A binary min-heap of grid cells, ordered by walking cost.
private struct CellHeap {
    private var entries: [(cost: Int, cell: Int)] = []

    mutating func push(cost: Int, cell: Int) {
        entries.append((cost, cell))
        var child = entries.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard entries[child].cost < entries[parent].cost else { break }
            entries.swapAt(child, parent)
            child = parent
        }
    }

    mutating func popMin() -> (cost: Int, cell: Int)? {
        guard let smallest = entries.first else { return nil }
        let last = entries.removeLast()
        guard !entries.isEmpty else { return smallest }

        entries[0] = last
        var parent = 0
        while 2 * parent + 1 < entries.count {
            var child = 2 * parent + 1
            if child + 1 < entries.count && entries[child + 1].cost < entries[child].cost {
                child += 1
            }
            guard entries[child].cost < entries[parent].cost else { break }
            entries.swapAt(parent, child)
            parent = child
        }
        return smallest
    }
}

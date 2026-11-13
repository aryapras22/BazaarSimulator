import Foundation
import simd

nonisolated enum CrowdFlowTarget: Hashable {
    case exit
    case gate(Int)
    case booth(Int)
    case table(Int)
}

/// For every cell, the walking cost to one target and the direction to walk.
nonisolated final class CrowdFlowField {
    let costs: [Float]
    private let directions: [Int8]

    init(costs: [Float], directions: [Int8]) {
        self.costs = costs
        self.directions = directions
    }

    func direction(atCell cell: Int) -> SIMD2<Double> {
        SIMD2(Double(directions[2 * cell]), Double(directions[2 * cell + 1])) / 127
    }
}

private nonisolated struct CrowdCostHeap {
    private var entries: [(cost: Float, cell: Int)] = []

    mutating func push(cost: Float, cell: Int) {
        entries.append((cost, cell))
        var child = entries.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard entries[child].cost < entries[parent].cost else { break }
            entries.swapAt(child, parent)
            child = parent
        }
    }

    mutating func popMin() -> (cost: Float, cell: Int)? {
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

nonisolated extension CrowdWorld {
    private static let lookAheadCells = CrowdParameters.flowLookAheadCells
    private static let neighborSteps: [(col: Int, row: Int)] = [
        (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)
    ]

    func flowField(to target: CrowdFlowTarget) -> CrowdFlowField {
        if let cached = fieldCache[target] { return cached }

        let blocked = target == .exit ? outboundBlocked : inboundBlocked
        let field = makeField(sources: sourceCells(for: target), blocked: blocked)
        fieldCache[target] = field
        return field
    }

    private func sourceCells(for target: CrowdFlowTarget) -> [Int] {
        switch target {
        case .exit:
            return exits.flatMap { cells(within: CrowdParameters.boothBrowseRingRadiusM, of: $0) }
        case .gate(let index):
            return cells(within: CrowdParameters.gateCrowdCheckRadiusM, of: gates[index])
        case .booth(let index):
            return ringCells(around: booths[index].footprint, from: 0, to: CrowdParameters.boothBrowseRingRadiusM)
        case .table(let index):
            return ringCells(around: tables[index].footprint, from: 0, to: CrowdParameters.tableArrivalRingRadiusM)
        }
    }

    private func makeField(sources: [Int], blocked: [Bool]) -> CrowdFlowField {
        let costs = routeCosts(from: sources, blocked: blocked)
        let nextCells = (0..<cellCount).map { nextCell(from: $0, costs: costs, blocked: blocked) }

        var directions = [Int8](repeating: 0, count: cellCount * 2)
        for cell in 0..<cellCount where nextCells[cell] >= 0 {
            var ahead = cell
            for _ in 0..<Self.lookAheadCells where nextCells[ahead] >= 0 {
                ahead = nextCells[ahead]
            }
            let offset = SIMD2(Double(ahead % cols - cell % cols), Double(ahead / cols - cell / cols))
            let unit = simd_length(offset) == 0 ? offset : simd_normalize(offset)
            directions[2 * cell] = Int8((unit.x * 127).rounded())
            directions[2 * cell + 1] = Int8((unit.y * 127).rounded())
        }
        return CrowdFlowField(costs: costs, directions: directions)
    }

    /// Dijkstra from the target outward, so a cell's cost is the price of walking from it to the target.
    /// Search edges run backward: reaching `next` from `current` means a person walks from `next` into `current`.
    private func routeCosts(from sources: [Int], blocked: [Bool]) -> [Float] {
        var costs = [Float](repeating: .infinity, count: cellCount)
        var frontier = CrowdCostHeap()
        for source in sources {
            costs[source] = 0
            frontier.push(cost: 0, cell: source)
        }

        while let (cost, current) = frontier.popMin() {
            guard cost == costs[current] else { continue }

            for stepIndex in Self.neighborSteps.indices {
                guard let next = neighbor(of: current, stepIndex: stepIndex) else { continue }
                // A person may leave a one-way door cell but may not step into one from open floor.
                if blocked[current] && !blocked[next] { continue }
                let length: Float = stepIndex < 4 ? 1.0 : 1.4142135
                let penalty = Self.wallPenalty(walls.wallDistances[next])
                let nextCost = cost + length * Float(Self.cellSize) * (1 + penalty)
                if nextCost < costs[next] {
                    costs[next] = nextCost
                    frontier.push(cost: nextCost, cell: next)
                }
            }
        }
        return costs
    }

    private func nextCell(from cell: Int, costs: [Float], blocked: [Bool]) -> Int {
        guard walls.floor[cell], costs[cell].isFinite else { return -1 }
        var best = costs[cell]
        var bestCell = -1
        for stepIndex in Self.neighborSteps.indices {
            guard let next = neighbor(of: cell, stepIndex: stepIndex) else { continue }
            if !blocked[cell] && blocked[next] { continue }
            if costs[next] < best - 1e-6 {
                best = costs[next]
                bestCell = next
            }
        }
        return bestCell
    }

    private func neighbor(of cell: Int, stepIndex: Int) -> Int? {
        let step = Self.neighborSteps[stepIndex]
        let col = cell % cols
        let row = cell / cols
        let nextCol = col + step.col
        let nextRow = row + step.row
        guard nextCol >= 0, nextRow >= 0, nextCol < cols, nextRow < rows else { return nil }
        // Both side cells must be open too, or a diagonal would cut through a corner.
        let floor = walls.floor
        guard floor[nextRow * cols + nextCol], floor[row * cols + nextCol], floor[nextRow * cols + col] else {
            return nil
        }
        return nextRow * cols + nextCol
    }

    /// Extra cost that keeps routes away from walls and rules out gaps too narrow to walk.
    private static func wallPenalty(_ distance: Float) -> Float {
        if distance < CrowdParameters.wallPenaltyBlockedDistanceM {
            return CrowdParameters.wallPenaltyBlockedCost
        }
        if distance < CrowdParameters.wallPenaltyTightDistanceM {
            return CrowdParameters.wallPenaltyTightCost
        }
        if distance < CrowdParameters.wallPenaltyBufferDistanceM {
            let buffer = CrowdParameters.wallPenaltyBufferDistanceM
            let span = buffer - CrowdParameters.wallPenaltyTightDistanceM
            return CrowdParameters.wallPenaltyBufferScale * (buffer - distance) / span
        }
        return 0
    }
}

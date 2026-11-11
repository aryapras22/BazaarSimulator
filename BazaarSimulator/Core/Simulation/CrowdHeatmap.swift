import Foundation
import simd

/// Turns visitor positions into smoothed density cells, in real people per square metre.
nonisolated struct CrowdHeatmap {
    /// Spread keeps one standing person at about 0.073 /m², inside grade A's limit of 0.08.
    private static let kernel: [(offset: SIMD2<Int>, weight: Double)] = {
        let twoSigmaSq = 2.0 * 1.5 * 1.5
        var entries: [(offset: SIMD2<Int>, weight: Double)] = []
        for dRow in -3...3 {
            for dCol in -3...3 {
                entries.append((SIMD2(dCol, dRow), exp(-Double(dCol * dCol + dRow * dRow) / twoSigmaSq)))
            }
        }
        let total = entries.reduce(0.0) { $0 + $1.weight }
        return entries.map { (offset: $0.offset, weight: $0.weight / total) }
    }()

    private let cols: Int
    private let rows: Int
    private var smoothed: [Double]
    private var occupiedUpdates = 0

    private(set) var cells: [DensityCell] = []
    private(set) var peakCellsByID: [Int: DensityCell] = [:]
    private(set) var meanDensity = 0.0
    private(set) var peakDensity = 0.0

    init(sizeM: SIMD2<Double>) {
        cols = max(1, Int(ceil(sizeM.x)))
        rows = max(1, Int(ceil(sizeM.y)))
        smoothed = Array(repeating: 0, count: cols * rows)
    }

    mutating func update(with visitors: [SimulatedVisitor]) {
        let instant = instantDensity(of: visitors)
        var activeCells: [DensityCell] = []

        for key in smoothed.indices {
            let value = smoothed[key] * 0.72 + instant[key] * 0.28
            guard value >= 0.004 else {
                smoothed[key] = 0
                continue
            }
            smoothed[key] = value
            let center = SIMD2(Double(key % cols) + 0.5, Double(key / cols) + 0.5)
            let cell = DensityCell(id: key, center: center, peoplePerSquareMetre: value)
            activeCells.append(cell)
            if (peakCellsByID[key]?.peoplePerSquareMetre ?? 0) < value {
                peakCellsByID[key] = cell
            }
        }

        cells = activeCells
        if !cells.isEmpty {
            let currentMean = cells.reduce(0.0) { $0 + $1.peoplePerSquareMetre } / Double(cells.count)
            occupiedUpdates += 1
            meanDensity += (currentMean - meanDensity) / Double(occupiedUpdates)
        }
        peakDensity = max(peakDensity, cells.map(\.peoplePerSquareMetre).max() ?? 0)
    }

    private func instantDensity(of visitors: [SimulatedVisitor]) -> [Double] {
        var instant = [Double](repeating: 0, count: cols * rows)
        for visitor in visitors {
            let col = Int(visitor.position.x)
            let row = Int(visitor.position.y)
            let people = Double(visitor.peopleCount)
            for entry in Self.kernel {
                let nCol = col + entry.offset.x
                let nRow = row + entry.offset.y
                guard nCol >= 0, nRow >= 0, nCol < cols, nRow < rows else { continue }
                instant[nRow * cols + nCol] += people * entry.weight
            }
        }
        return instant
    }
}

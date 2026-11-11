import Foundation
import simd

extension SimulationEngine {
    /// Spread keeps one standing person at about 0.073 /m², inside grade A's limit of 0.08.
    private static let densityKernel: [(offset: SIMD2<Int>, weight: Double)] = {
        let twoSigmaSq = 2.0 * 1.5 * 1.5
        var kernel: [(offset: SIMD2<Int>, weight: Double)] = []
        for dRow in -3...3 {
            for dCol in -3...3 {
                kernel.append((SIMD2(dCol, dRow), exp(-Double(dCol * dCol + dRow * dRow) / twoSigmaSq)))
            }
        }
        let total = kernel.reduce(0.0) { $0 + $1.weight }
        return kernel.map { (offset: $0.offset, weight: $0.weight / total) }
    }()

    func updateDensityCells() {
        let bucketSize = 1.0
        let bucketCols = max(1, Int(ceil(layout.sizeM.x / bucketSize)))
        let bucketRows = max(1, Int(ceil(layout.sizeM.y / bucketSize)))
        let instantByCell = computeKernelDensity(
            bucketSize: bucketSize,
            bucketCols: bucketCols,
            bucketRows: bucketRows
        )

        if smoothedDensity.isEmpty {
            smoothedDensity = Array(repeating: 0, count: bucketCols * bucketRows)
        }
        var activeCells: [DensityCell] = []

        for key in smoothedDensity.indices {
            let smoothed = smoothedDensity[key] * 0.72 + instantByCell[key] * 0.28
            guard smoothed >= 0.004 else {
                smoothedDensity[key] = 0
                continue
            }
            smoothedDensity[key] = smoothed
            let col = key % bucketCols
            let row = key / bucketCols
            let center = SIMD2<Double>((Double(col) + 0.5) * bucketSize, (Double(row) + 0.5) * bucketSize)
            let cell = DensityCell(id: key, center: center, peoplePerSquareMetre: smoothed)
            activeCells.append(cell)

            if (peakCellsByID[key]?.peoplePerSquareMetre ?? 0) < smoothed {
                peakCellsByID[key] = cell
            }
        }

        densityCells = activeCells
        if !densityCells.isEmpty {
            let totalDensity = densityCells.reduce(0.0) { $0 + $1.peoplePerSquareMetre }
            let currentMean = totalDensity / Double(densityCells.count)
            occupiedDensityUpdates += 1
            metrics.meanDensity += (currentMean - metrics.meanDensity) / Double(occupiedDensityUpdates)
        }
        metrics.peakDensity = max(metrics.peakDensity, densityCells.map(\.peoplePerSquareMetre).max() ?? 0)
    }

    private func computeKernelDensity(
        bucketSize: Double,
        bucketCols: Int,
        bucketRows: Int
    ) -> [Double] {
        var instantByCell = [Double](repeating: 0, count: bucketCols * bucketRows)

        for visitor in visitors {
            let col = Int(visitor.position.x / bucketSize)
            let row = Int(visitor.position.y / bucketSize)
            let people = Double(visitor.peopleCount)

            for cell in Self.densityKernel {
                let nCol = col + cell.offset.x
                let nRow = row + cell.offset.y
                guard nCol >= 0, nRow >= 0, nCol < bucketCols, nRow < bucketRows else { continue }
                instantByCell[nRow * bucketCols + nCol] += people * cell.weight
            }
        }
        return instantByCell
    }
}

import Foundation
import simd

extension SimulationEngine {
    func updateDensityCells() {
        let bucketSize = 1.0
        let bucketCols = max(1, Int(ceil(layout.sizeM.x / bucketSize)))
        let bucketRows = max(1, Int(ceil(layout.sizeM.y / bucketSize)))
        let instantByCell = computeKernelDensity(
            bucketSize: bucketSize,
            bucketCols: bucketCols,
            bucketRows: bucketRows
        )

        let allKeys = Set(smoothedDensityByCell.keys).union(instantByCell.keys).sorted()
        var activeCells: [DensityCell] = []

        for key in allKeys {
            let instant = instantByCell[key] ?? 0.0
            let smoothed = (smoothedDensityByCell[key] ?? 0.0) * 0.72 + instant * 0.28
            if smoothed < 0.004 {
                smoothedDensityByCell.removeValue(forKey: key)
                continue
            }
            smoothedDensityByCell[key] = smoothed
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
    ) -> [Int: Double] {
        // This spread keeps one standing person at about 0.073 /m², inside grade A's limit of 0.08.
        let twoSigmaSq = 2.0 * 1.5 * 1.5
        var kernel: [(offset: SIMD2<Int>, weight: Double)] = []
        for dRow in -3...3 {
            for dCol in -3...3 {
                kernel.append((SIMD2(dCol, dRow), exp(-Double(dCol * dCol + dRow * dRow) / twoSigmaSq)))
            }
        }
        let kernelTotal = kernel.reduce(0.0) { $0 + $1.weight }
        var instantByCell: [Int: Double] = [:]

        for visitor in visitors {
            let col = Int(visitor.position.x / bucketSize)
            let row = Int(visitor.position.y / bucketSize)
            let people = Double(visitor.peopleCount)

            for cell in kernel {
                let nCol = col + cell.offset.x
                let nRow = row + cell.offset.y
                guard nCol >= 0, nRow >= 0, nCol < bucketCols, nRow < bucketRows else { continue }
                instantByCell[nRow * bucketCols + nCol, default: 0.0] += people * cell.weight / kernelTotal
            }
        }
        return instantByCell
    }
}

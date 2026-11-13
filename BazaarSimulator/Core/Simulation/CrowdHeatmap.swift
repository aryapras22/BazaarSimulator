import Foundation
import simd

/// Turns visitor positions into smoothed density cells, in real people per square metre,
/// loosened proportionally for large total visitor counts.
nonisolated struct CrowdHeatmap {
    /// Spread keeps one standing person at about 0.073 /m², inside grade A's limit of 0.08.
    private static let kernel: [(offset: SIMD2<Int>, weight: Double)] = {
        let radius = CrowdParameters.heatmapKernelRadius
        let sigma = CrowdParameters.heatmapKernelSigma
        let twoSigmaSq = 2.0 * sigma * sigma
        var entries: [(offset: SIMD2<Int>, weight: Double)] = []
        for dRow in -radius...radius {
            for dCol in -radius...radius {
                entries.append((SIMD2(dCol, dRow), exp(-Double(dCol * dCol + dRow * dRow) / twoSigmaSq)))
            }
        }
        let total = entries.reduce(0.0) { $0 + $1.weight }
        return entries.map { (offset: $0.offset, weight: $0.weight / total) }
    }()

    private let cols: Int
    private let rows: Int
    private let visitorScale: Double
    private var smoothed: [Double]
    private var cumulative: [Double]
    private var cellPeak: [Double]
    private var scratchInstant: [Double]
    private var occupiedUpdates = 0

    private(set) var cells: [DensityCell] = []
    private(set) var meanDensity = 0.0
    private(set) var peakDensity = 0.0

    init(sizeM: SIMD2<Double>, totalVisitors: Int = CrowdParameters.heatmapReferenceVisitors) {
        cols = max(1, Int(ceil(sizeM.x)))
        rows = max(1, Int(ceil(sizeM.y)))
        visitorScale = CrowdParameters.visitorDensityScale(for: totalVisitors)
        let cellCount = cols * rows
        smoothed = Array(repeating: 0, count: cellCount)
        cumulative = Array(repeating: 0, count: cellCount)
        cellPeak = Array(repeating: 0, count: cellCount)
        scratchInstant = Array(repeating: 0, count: cellCount)
    }

    mutating func update(with visitors: [SimulatedVisitor]) {
        if visitors.isEmpty && cells.isEmpty { return }
        fillInstantDensity(from: visitors)
        commitSmoothedDensity()
    }

    mutating func update(withAgents agents: [CrowdAgent]) {
        if agents.isEmpty && cells.isEmpty { return }
        fillInstantDensity(fromAgents: agents)
        commitSmoothedDensity()
    }

    /// Computes the loosened final summary heatmap across the whole event, blending each cell's
    /// time-averaged density with a small share of its peak so transient passings do not saturate red.
    func finalSummaryCells() -> [DensityCell] {
        let updates = Double(max(1, occupiedUpdates))
        let meanWeight = CrowdParameters.finalHeatmapMeanWeight
        let peakWeight = CrowdParameters.finalHeatmapPeakWeight
        let loosen = CrowdParameters.finalHeatmapLooseningFactor
        let minActive = CrowdParameters.heatmapMinActiveDensity

        var summary: [DensityCell] = []
        for key in cumulative.indices where cellPeak[key] >= minActive {
            let avgValue = cumulative[key] / updates
            let blended = (avgValue * meanWeight + cellPeak[key] * peakWeight) * loosen
            let finalValue = max(minActive, blended)
            let center = SIMD2(Double(key % cols) + 0.5, Double(key / cols) + 0.5)
            summary.append(DensityCell(id: key, center: center, peoplePerSquareMetre: finalValue))
        }
        return summary
    }

    /// Peak density of the loosened final summary heatmap.
    var summaryPeakDensity: Double {
        let summaryMax = finalSummaryCells().map(\.peoplePerSquareMetre).max() ?? 0
        return max(summaryMax, peakDensity * CrowdParameters.finalHeatmapLooseningFactor)
    }

    private mutating func commitSmoothedDensity() {
        var activeCells: [DensityCell] = []
        activeCells.reserveCapacity(cells.count)
        let retain = CrowdParameters.heatmapSmoothingRetain
        let fresh = CrowdParameters.heatmapSmoothingNew
        let minActive = CrowdParameters.heatmapMinActiveDensity
        var currentMax = 0.0
        var currentSum = 0.0

        for key in smoothed.indices {
            let value = smoothed[key] * retain + scratchInstant[key] * fresh
            guard value >= minActive else {
                smoothed[key] = 0
                continue
            }
            smoothed[key] = value
            cumulative[key] += value
            if value > cellPeak[key] { cellPeak[key] = value }
            if value > currentMax { currentMax = value }
            currentSum += value

            let center = SIMD2(Double(key % cols) + 0.5, Double(key / cols) + 0.5)
            activeCells.append(DensityCell(id: key, center: center, peoplePerSquareMetre: value))
        }

        cells = activeCells
        if !cells.isEmpty {
            let currentMean = currentSum / Double(cells.count)
            occupiedUpdates += 1
            meanDensity += (currentMean - meanDensity) / Double(occupiedUpdates)
        }
        if currentMax > peakDensity { peakDensity = currentMax }
    }

    private mutating func fillInstantDensity(from visitors: [SimulatedVisitor]) {
        for index in scratchInstant.indices { scratchInstant[index] = 0 }
        for visitor in visitors {
            splatKernel(at: visitor.position, people: Double(visitor.peopleCount) * visitorScale)
        }
    }

    private mutating func fillInstantDensity(fromAgents agents: [CrowdAgent]) {
        for index in scratchInstant.indices { scratchInstant[index] = 0 }
        for agent in agents {
            splatKernel(at: agent.position, people: agent.weight * visitorScale)
        }
    }

    private mutating func splatKernel(at position: SIMD2<Double>, people: Double) {
        let col = Int(position.x)
        let row = Int(position.y)
        for entry in Self.kernel {
            let nCol = col + entry.offset.x
            let nRow = row + entry.offset.y
            guard nCol >= 0, nRow >= 0, nCol < cols, nRow < rows else { continue }
            scratchInstant[nRow * cols + nCol] += people * entry.weight
        }
    }
}

import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("SpotSelectorTests")
struct SpotSelectorTests {
    /// Blocks laid out in a row, `gap` metres apart. Every block is big enough to be a candidate.
    private func row(count: Int, gap: Double) -> (candidates: [SpotSelector.Candidate], centers: [SIMD2<Double>]) {
        let candidates = (0..<count).map { SpotSelector.Candidate(block: $0, areaM2: 20) }
        let centers = (0..<count).map { SIMD2<Double>(Double($0) * gap, 0) }
        return (candidates, centers)
    }

    @Test("Every block that is stuck is kept, with no fixed number of spots")
    func keepsAllStuckBlocks() {
        let blocks = row(count: 9, gap: 10)
        let peaks = Array(repeating: 1.2, count: 9)
        let chosen = SpotSelector.select(
            candidates: blocks.candidates, peaks: peaks, dayPeaks: peaks, centers: blocks.centers
        )
        #expect(chosen.count == 9)
    }

    @Test("A calm layout still keeps its most crowded block, so there is a worst spot to report")
    func keepsTheMostCrowdedWhenNothingIsStuck() {
        let blocks = row(count: 5, gap: 10)
        let peaks = [0.1, 0.5, 0.3, 0.2, 0.4]
        let chosen = SpotSelector.select(
            candidates: blocks.candidates, peaks: peaks, dayPeaks: peaks, centers: blocks.centers
        )
        #expect(chosen == [1])
    }

    @Test("After the most crowded block, only blocks that reach the stuck density are kept")
    func dropsBlocksBelowTheStuckDensity() {
        let blocks = row(count: 4, gap: 10)
        let peaks = [1.5, 0.9, 0.5, 0.71]
        let chosen = SpotSelector.select(
            candidates: blocks.candidates, peaks: peaks, dayPeaks: peaks, centers: blocks.centers
        )
        #expect(chosen == [0, 1])
    }

    @Test("A stuck block within the separation of a chosen one is skipped")
    func keepsSpotsApart() {
        let blocks = row(count: 3, gap: SpotSelector.minimumSeparationM / 2)
        let peaks = [2.0, 1.9, 1.8]
        let chosen = SpotSelector.select(
            candidates: blocks.candidates, peaks: peaks, dayPeaks: peaks, centers: blocks.centers
        )
        // Blocks 0 and 2 are a full separation apart, and block 1 sits between them.
        #expect(chosen == [0, 2])
    }
}

import Foundation

struct RulerScale: Equatable, Sendable {
    static let niceStepsM: [Double] = [0.5, 1, 2, 5, 10, 20, 50, 100]
    static let minLabelSpacingPt: Double = 64
    static let minTickSpacingPt: Double = 6
    static let minGridSpacingPt: Double = 8
    static let gridMinorCandidatesM: [Double] = [0.5, 1, 5, 10]
    static let gridMajorCandidatesM: [Double] = [1, 5, 10, 50, 100]
    private static let scaleBarTargetPt: Double = 120
    private static let scaleBarRangePt: ClosedRange<Double> = 80...200

    let labelStepM: Double
    let tickStepM: Double?
    let gridMinorM: Double
    let gridMajorM: Double

    init(pointsPerMetre scale: Double) {
        labelStepM = Self.niceStepsM.first { $0 * scale >= Self.minLabelSpacingPt } ?? 100
        let divisor: Double = labelStepM == 2 ? 4 : (labelStepM == 0.5 ? 2 : 5)
        let tick = labelStepM / divisor
        tickStepM = tick * scale >= Self.minTickSpacingPt ? tick : nil
        let minor = Self.gridMinorCandidatesM.first { $0 * scale >= Self.minGridSpacingPt } ?? 10
        gridMinorM = minor
        gridMajorM = Self.gridMajorCandidatesM.first { $0 >= minor * 5 } ?? 100
    }

    static func scaleBarLengthM(pointsPerMetre scale: Double) -> Double {
        let candidates = niceStepsM.filter { scaleBarRangePt.contains($0 * scale) }
        let pool = candidates.isEmpty ? niceStepsM : candidates
        return pool.min { abs($0 * scale - scaleBarTargetPt) < abs($1 * scale - scaleBarTargetPt) } ?? 10
    }
}

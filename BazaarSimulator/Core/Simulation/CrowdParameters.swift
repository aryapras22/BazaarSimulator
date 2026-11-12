import Foundation

nonisolated struct CrowdPersona: Sendable {
    let key: String
    let isFamily: Bool
    let aloneChance: Double
    /// Goal-driven parties walk to planned booths. The others stroll the hall and stop on the way.
    let isGoalDriven: Bool
    let dwellSeconds: ClosedRange<Double>
    let plannedBooths: ClosedRange<Int>
    let foodShare: Double
    /// A visible booth whose pull beats this score draws the party off its plan.
    let loyalty: Double
    let sitChance: Double
    let stopovers: Int
}

/// Values from the crowd behaviour research. Comments mark the ones that are assumptions.
nonisolated enum CrowdParameters {
    static let stepsPerSecond = 10
    static let stepSeconds = 1.0 / Double(stepsPerSecond)
    static let thinkInterval = 0.5

    static let walkAlone = 1.52
    static let walkGroup = 1.36
    static let walkWithKids = 1.39
    /// Assumption: the spread inside a group type and the limits of one visitor's speed.
    static let speedSpread = 0.12
    static let speedLimits = 0.54...2.0

    static let carriedShareOfKids = 0.75
    static let twoKidsShare = 0.5
    static let pairShare = 0.81

    static let stopoverSeconds = 35.0...120.0
    static let medianEatSeconds = 240.0
    static let viewAngleDegrees = 150.0
    static let viewDepth = 10.0
    static let influenceRadius = 3.75
    static let maxDetours = 1
    /// No party passes four people, so a group of four chairs in a seating block seats any party.
    static let seatsPerGroup = 4
    static let stuckSeconds = 150.0

    static let doorFlowPerMetre = 1.95
    /// A goods booth smaller than this spills its stock into the walkway.
    static let stockArea = 4.0
    static let cornerSlowdown = 0.25
    static let cornerRadius = 2.5

    /// Weidmann speed-density curve: 1 - exp(-gamma (1/density - 1/jam)).
    static let densityRadius = 1.5
    static let jamDensity = 5.4
    static let weidmannGamma = 1.913
    static let minimumCrowdFactor = 0.08

    /// Side by side spacing of a walking group, the midpoints of 0.78-0.93 m and 0.54-0.67 m.
    static let sideSpacingQuiet = 0.855
    static let sideSpacingBusy = 0.605
    static let quietDensity = 0.27
    static let busyDensity = 0.72

    static let social = CrowdPersona(
        key: "social", isFamily: false, aloneChance: 0.4, isGoalDriven: true, dwellSeconds: 120...239,
        plannedBooths: 2...4, foodShare: 0.5, loyalty: 3.5, sitChance: 0.5, stopovers: 0
    )
    static let family = CrowdPersona(
        key: "family", isFamily: true, aloneChance: 0, isGoalDriven: true, dwellSeconds: 100...239,
        plannedBooths: 3...5, foodShare: 0.4, loyalty: 3.5, sitChance: 0.6, stopovers: 0
    )
    static let stroller = CrowdPersona(
        key: "stroller", isFamily: false, aloneChance: 0, isGoalDriven: false, dwellSeconds: 60...150,
        plannedBooths: 1...2, foodShare: 0.7, loyalty: 0, sitChance: 0, stopovers: 2
    )
    static let buyer = CrowdPersona(
        key: "buyer", isFamily: false, aloneChance: 0.8, isGoalDriven: true, dwellSeconds: 35...90,
        plannedBooths: 1...2, foodShare: 0.8, loyalty: 4.5, sitChance: 0, stopovers: 0
    )
}

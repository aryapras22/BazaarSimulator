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

/// Centralized configuration file for all crowd simulation parameters, physics rules, and agent behaviors.
/// Edit values here to experiment with tick rate, walking speeds, social forces, loyalty, walls, and heatmaps.
nonisolated enum CrowdParameters {

    // MARK: - 1. Simulation Timing & Recording

    /// Number of simulation steps per simulated second (`4` = `0.25s` per tick; `10` = `0.10s` per tick).
    static let stepsPerSecond = 4
    /// Duration of a single simulation step in seconds (`dt`).
    static let stepSeconds = 1.0 / Double(stepsPerSecond)
    /// How often (in simulated seconds) each party re-evaluates its target, detours, and queue state.
    static let thinkInterval = 0.5
    /// Default interval (in simulated seconds) between recorded replay frames.
    static let defaultFrameIntervalSeconds = 10.0
    /// How often (in simulated seconds) the live heatmap refreshes.
    static let liveDensityUpdateIntervalSeconds = 1.0
    /// Minimum agent count before parallelizing the steering pass across CPU cores.
    static let minimumAgentsForThreads = 400
    /// Chunk size of agents per parallel work item.
    static let parallelChunkSize = 64

    // MARK: - 2. World Grid, Walls, Doors & Booths

    /// Size of each walkable floor grid cell in metres.
    static let worldCellSize = 0.25
    /// Route cost threshold above which a booth or table is considered unreachable.
    static let reachableCostLimit: Float = 700
    /// Number of cells to look ahead when smoothing flow-field direction vectors.
    static let flowLookAheadCells = 4
    /// Minimum carved width and depth (in metres) around active doors so agents can pass through cleanly.
    static let doorCarvedMinWidthM = 1.4
    static let doorCarvedMinDepthM = 1.6
    /// Default doorway width (in metres) when a layout has spawn markers but no door objects.
    static let fallbackDoorWidthM = 2.0
    /// Step size (in metres) when raycasting line-of-sight across the floor grid.
    static let lineOfSightStepM = 0.4
    /// Offset (in metres) used to compute the wall distance gradient vector.
    static let wallGradientOffsetM = 0.12

    /// Wall distance thresholds and penalties used by flow-field pathfinding to keep routes off walls.
    static let wallPenaltyBlockedDistanceM: Float = 0.2
    static let wallPenaltyBlockedCost: Float = 3000
    static let wallPenaltyTightDistanceM: Float = 0.3
    static let wallPenaltyTightCost: Float = 20
    static let wallPenaltyBufferDistanceM: Float = 0.7
    static let wallPenaltyBufferScale: Float = 3.0

    /// A goods booth smaller than this area (m²) spills its stock into the walkway.
    static let stockArea = 4.0
    /// Booth counter length (in metres) required per simultaneous browsing party.
    static let boothLengthPerBrowserM = 0.75
    /// Ring outer radius (in metres) around a booth where visitors can stand to browse.
    static let boothBrowseRingRadiusM = 0.8
    /// Ring outer radius (in metres) around a table or seat group for arrival.
    static let tableArrivalRingRadiusM = 0.6

    // MARK: - 3. Entrances, Arrivals & Queue Rules

    /// Maximum flow of people per metre of door width per second.
    static let doorFlowPerMetre = 1.95
    /// Initial gate token allowance when the simulation starts.
    static let initialGateTokens = 3.0
    /// Maximum number of agents allowed within `gateCrowdCheckRadiusM` of a gate before new spawns wait outside.
    static let maxAgentsNearGate = 9
    static let gateCrowdCheckRadiusM = 1.2
    /// Default maximum number of parties in a booth queue before arriving parties balk (skip the booth).
    static let defaultMaxQueueLength = 6
    /// Default maximum time (in seconds) a party will wait in a queue before giving up.
    static let defaultMaxQueueWaitSeconds = 270.0
    /// Queue spacing parameters (distance from counter for rank 0, gap between parties, and per-walker spacing).
    static let queueCounterOffsetM = 0.3
    static let queuePartyGapM = 0.35
    static let queueWalkerSpacingM = 0.3
    static let queueHoldToleranceM = 0.15
    static let queueAdvanceMaxSpeed = 0.9
    static let queueFrontStartCost = 0.9

    // MARK: - 4. Walking Speeds, Group Formations & Weidmann Curve

    static let walkAlone = 1.52
    static let walkGroup = 1.36
    static let walkWithKids = 1.39
    /// Standard deviation of individual party speed variation and hard speed bounds (m/s).
    static let speedSpread = 0.12
    static let speedLimits = 0.54...2.0

    /// Physical body radii (in metres) and people-weights for adults, kids, and adults carrying kids.
    static let adultRadiusM = 0.25
    static let kidRadiusM = 0.18
    static let carryingAdultRadiusM = 0.32
    static let adultPeopleWeight = 1.0
    static let carryingAdultPeopleWeight = 2.0

    /// Nobody is let in this long before closing, and everyone still inside is sent out this long before closing,
    /// so the hall is empty when the event ends. Set by judgement, not from the crowd behaviour research.
    static let lastEntrySeconds = 1800.0
    static let clearingSeconds = 600.0

    /// Slowdown near inner hall corners.
    static let cornerSlowdown = 0.25
    static let cornerRadius = 2.5

    /// Weidmann speed-density curve: `1 - exp(-gamma * (1/density - 1/jamDensity))`.
    static let densityRadius = 1.5
    static let jamDensity = 5.4
    static let weidmannGamma = 1.913
    static let minimumCrowdFactor = 0.08

    /// Side-by-side spacing (in metres) of a walking group, narrowing as local crowd density increases.
    static let sideSpacingQuiet = 0.855
    static let sideSpacingBusy = 0.605
    static let quietDensity = 0.27
    static let busyDensity = 0.72

    /// Leader slowdown when group followers fall behind in dense aisles.
    static let leaderFarLagDistanceM = 3.2
    static let leaderFarLagSpeedFactor = 0.55
    static let leaderNearLagDistanceM = 2.2
    static let leaderNearLagSpeedFactor = 0.85

    // MARK: - 5. Agent Behavioral Rules (Vision, Detours, Dwell, Seating & Grazing)

    static let carriedShareOfKids = 0.75
    static let twoKidsShare = 0.5
    static let pairShare = 0.81
    static let loyaltyRandomSpread = 3.0
    static let maxLoyaltyScore = 12.0

    static let stopoverSeconds = 35.0...120.0
    static let medianEatSeconds = 240.0
    static let eatDurationLogSigma = 0.4
    static let minimumSeatedSeconds = 30.0
    static let viewAngleDegrees = 150.0
    static let viewDepth = 10.0
    static let influenceRadius = 3.75
    static let maxDetours = 1

    /// Maximum chairs per seating group (no party exceeds 4 people).
    static let seatsPerGroup = 4
    /// Maximum distance (m) party members can be from the leader before sitting down together.
    static let seatCatchUpRadiusM = 3.5
    /// Entertainment audience rules: chance to sit and watch, search radius (m), and watch duration (s).
    static let audienceChance = 0.5
    static let audienceRadiusM = 15.0
    static let watchSeconds = 300.0...900.0
    /// Seconds without route cost progress before a party abandons a blocked target.
    static let stuckSeconds = 150.0
    static let progressCostDropThreshold = 0.8

    /// Window-shopping ("booth grazing") rule: parties slow down slightly when strolling past high-pull booths.
    static let windowShoppingRadiusM = 2.2
    static let windowShoppingMinPull = 4.0
    static let windowShoppingSpeedFactor = 0.88

    /// Visitor fatigue rule: after staying longer than `fatigueOnsetSeconds`, walking speed gently decreases.
    static let fatigueOnsetSeconds = 2700.0
    static let fatigueMaxSlowdownFactor = 0.88

    // MARK: - 6. Steering & Helbing Social Forces Model

    /// Spatial hash cell size (in metres) for neighbor lookups.
    static let spatialHashBinSize = 1.5
    /// Maximum nearby agents considered during local steering and social force calculation.
    static let maxNeighbors = 48
    /// Search radius squared (in m²) for neighbor interaction (`2.5m` radius -> `6.25 m²`).
    static let neighborRadiusSquared = 6.25
    /// Candidate heading offsets (in radians) and speed fractions evaluated during collision avoidance.
    static let steeringHeadingOffsets: [Double] = [0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4]
    static let steeringSpeedFractions: [Double] = [1.0, 0.5]
    /// Time-to-collision horizon (in seconds) for anticipatory avoidance.
    static let timeToCollisionHorizon = 2.5
    /// Relaxation time `tau` (in seconds) for accelerating toward desired velocity.
    static let velocityRelaxationTau = 0.35
    /// Maximum multiple of base party speed allowed during catch-up or avoidance.
    static let maxSpeedMultiplier = 1.35

    /// Helbing Social Force Model: exponential pedestrian-pedestrian repulsion `A * exp((r - d) / B)`.
    static let socialForceStrength = 1.35
    static let socialForceRangeM = 0.32
    /// Anisotropy factor `lambda` in `[0, 1]`: `1.0` in front of the agent, `lambda` behind the agent.
    static let socialForceAnisotropyLambda = 0.35
    /// Helbing Wall Social Force: exponential repulsion from walls and booth boundaries.
    static let wallSocialForceStrength = 1.60
    static let wallSocialForceRangeM = 0.22
    /// Group cohesion social force: gentle pull keeping followers near their party leader.
    static let groupCohesionForceStrength = 0.28
    /// Right-hand traffic rule bias: lowers cost when passing oncoming agents on the right side.
    static let rightSidePassingBias = 0.18

    /// Hard overlap & wall constraint margins.
    static let overlapSeparationFactor = 0.97
    static let wallClearanceFactor = 0.85
    static let maxWallPushPerStepM = 0.25

    // MARK: - 7. Heatmap Parameters

    static let heatmapKernelRadius = 3
    static let heatmapKernelSigma = 1.5
    static let heatmapSmoothingRetain = 0.72
    static let heatmapSmoothingNew = 0.28
    static let heatmapMinActiveDensity = 0.004
    /// Sensitivity multiplier for the replay crowd-density heatmap so crowded spots reach orange/red
    /// while 1-2 people close together remain green.
    static let replayHeatmapSensitivity = 1.65

    // MARK: - 8. Visitor Personas

    static let social = CrowdPersona(
        key: "social", isFamily: false, aloneChance: 0.4, isGoalDriven: true, dwellSeconds: 120...239,
        plannedBooths: 2...4, foodShare: 0.5, loyalty: 3.5, sitChance: 0.5, stopovers: 0
    )
    static let family = CrowdPersona(
        key: "family", isFamily: true, aloneChance: 0, isGoalDriven: true, dwellSeconds: 100...239,
        plannedBooths: 3...5, foodShare: 0.4, loyalty: 3.5, sitChance: 0.6, stopovers: 0
    )
    static let explorer = CrowdPersona(
        key: "explorer", isFamily: false, aloneChance: 0, isGoalDriven: false, dwellSeconds: 60...150,
        plannedBooths: 1...2, foodShare: 0.7, loyalty: 0, sitChance: 0, stopovers: 2
    )
    static let buyer = CrowdPersona(
        key: "buyer", isFamily: false, aloneChance: 0.8, isGoalDriven: true, dwellSeconds: 35...90,
        plannedBooths: 1...2, foodShare: 0.8, loyalty: 4.5, sitChance: 0, stopovers: 0
    )
}

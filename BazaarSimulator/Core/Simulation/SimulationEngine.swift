import Foundation
import simd

/// Protocol for running a bazaar crowd simulation.
protocol SimulationEngineProtocol: AnyObject {
    var visitors: [SimulatedVisitor] { get }
    var metrics: SimulationMetrics { get }
    var densityCells: [DensityCell] { get }
    var isRunning: Bool { get }

    func start()
    func pause()
    func toggleRunning()
    func reset()
    func advance(realSeconds: Double, speed: Double)
    func fastForward(minutes: Int)
    func runWithRecordedFootage(durationMinutes: Int, frameIntervalSeconds: Double) -> SimulationResult
}

/// A lightweight, deterministic fixed-step crowd simulation engine.
/// Visitors enter through entrances, walk to booths, wait in short queues,
/// browse items, and leave through an exit.
final class SimulationEngine: SimulationEngineProtocol {
    var visitors: [SimulatedVisitor] = []
    var metrics = SimulationMetrics()
    var densityCells: [DensityCell] = []
    var isRunning = false

    let layout: Layout
    let booths: [LayoutObject]
    var settings: SimulationSettings
    var rng: SeededRandom
    var navGrid: NavigationGrid

    var nextVisitorID = 1
    var nextArrivalTime = 0.0
    var accumulatedTime = 0.0
    var nextDensityUpdate = 0.0
    var boothQueues: [UUID: [Int]] = [:]
    var boothServingCount: [UUID: Int] = [:]
    var boothByID: [UUID: LayoutObject] = [:]
    var stayDurations: [Double] = []
    var peakCellsByID: [Int: DensityCell] = [:]
    var smoothedDensityByCell: [Int: Double] = [:]

    init(layout: Layout, settings: SimulationSettings = SimulationSettings()) {
        self.layout = layout
        self.settings = settings
        self.booths = layout.objects.filter { $0.kind == .booth }
        self.rng = SeededRandom(seed: settings.randomSeed)
        self.navGrid = NavigationGrid(layout: layout)
        self.boothByID = Dictionary(uniqueKeysWithValues: booths.map { ($0.id, $0) })
        reset()
    }

    // MARK: - Playback Controls

    func start() { isRunning = true }
    func pause() { isRunning = false }
    func toggleRunning() { isRunning.toggle() }

    func reset() {
        isRunning = false
        rng = SeededRandom(seed: settings.randomSeed)
        visitors = []
        metrics = SimulationMetrics()
        densityCells = []
        peakCellsByID = [:]
        smoothedDensityByCell = [:]
        nextVisitorID = 1
        nextArrivalTime = 0.0
        accumulatedTime = 0.0
        nextDensityUpdate = 0.0
        boothQueues = [:]
        boothServingCount = [:]
        stayDurations = []

        for booth in booths {
            boothQueues[booth.id] = []
            boothServingCount[booth.id] = 0
        }
    }

    /// Advances the simulation using fixed 0.5-second steps so movement stays smooth at any speed.
    func advance(realSeconds: Double, speed: Double) {
        guard realSeconds > 0 else { return }
        accumulatedTime += min(realSeconds, 0.5) * max(0.5, speed)

        let stepSize = 0.5
        var stepsTaken = 0
        while accumulatedTime >= stepSize && stepsTaken < 240 {
            step(dt: stepSize)
            accumulatedTime -= stepSize
            stepsTaken += 1
        }
    }

    /// Quickly jumps the simulation forward by a given number of simulated minutes.
    func fastForward(minutes: Int) {
        let totalSteps = max(0, minutes * 120)
        for _ in 0..<totalSteps {
            step(dt: 0.5)
        }
    }

    /// Runs a full simulation over the configured event duration and saves heatmap cells and footage frames.
    func runWithRecordedFootage(
        durationMinutes: Int = 0,
        frameIntervalSeconds: Double = 5.0
    ) -> SimulationResult {
        reset()
        let targetMinutes = durationMinutes > 0 ? durationMinutes : max(1, settings.durationMinutes)
        let totalDurationSeconds = Double(targetMinutes * 60)
        let stepSize = 0.5
        let totalSteps = Int(totalDurationSeconds / stepSize)
        let stepsPerFrame = max(1, Int(frameIntervalSeconds / stepSize))
        var frames: [SimulationFrame] = []

        for stepIndex in 1...totalSteps {
            step(dt: stepSize)
            if stepIndex == 1 || stepIndex % stepsPerFrame == 0 || stepIndex == totalSteps {
                frames.append(
                    SimulationFrame(
                        elapsedSeconds: metrics.elapsedSeconds,
                        visitors: visitors,
                        densityCells: densityCells,
                        metrics: metrics
                    )
                )
            }
        }

        let summaryCells = peakCellsByID.values.sorted { $0.id < $1.id }
        return SimulationResult(
            layoutID: layout.id,
            layoutName: layout.name,
            durationSeconds: totalDurationSeconds,
            startMinutesFromMidnight: settings.startMinutesFromMidnight,
            metrics: metrics,
            densityCells: summaryCells,
            frames: frames
        )
    }

    // MARK: - Simulation Step

    func step(dt: Double) {
        metrics.elapsedSeconds += dt
        spawnNewVisitors()
        updateVisitors(dt: dt)

        if metrics.elapsedSeconds >= nextDensityUpdate {
            updateDensityCells()
            nextDensityUpdate = metrics.elapsedSeconds + 1.0
        }

        metrics.peopleInside = visitors.reduce(0) { $0 + $1.partySize }
        if !stayDurations.isEmpty {
            metrics.averageStaySeconds = stayDurations.reduce(0, +) / Double(stayDurations.count)
        }
    }

    private func spawnNewVisitors() {
        let arrivalRate = max(0.001, settings.arrivalsPer15Min / 900.0 / meanPartySize)
        var spawnedThisStep = 0
        while metrics.elapsedSeconds >= nextArrivalTime && spawnedThisStep < 6 {
            if metrics.arrivals < settings.totalVisitors {
                let visitor = createVisitor()
                visitors.append(visitor)
                metrics.arrivals += visitor.partySize
            }
            nextArrivalTime += rng.nextExponential(rate: arrivalRate)
            spawnedThisStep += 1
        }
    }

    /// `arrivalsPer15Min` counts people, while each arrival brings in a whole party.
    private var meanPartySize: Double {
        let largestGroup = Double(max(1, settings.maxGroupSize))
        let familyMean = (min(2, largestGroup) + largestGroup) / 2
        let otherMean = (1 + min(2, largestGroup)) / 2

        let familyWeight = max(0, settings.familyWeight)
        let totalWeight = max(0, settings.socializerWeight) + familyWeight
            + max(0, settings.strollerWeight) + max(0, settings.buyerWeight)
        guard totalWeight > 0 else { return otherMean }

        let familyShare = familyWeight / totalWeight
        return familyShare * familyMean + (1 - familyShare) * otherMean
    }

    private func createVisitor() -> SimulatedVisitor {
        let persona = pickWeightedPersona()
        let entrances = navGrid.entrancePoints
        let entrance = entrances[rng.randomInt(in: 0...max(0, entrances.count - 1))]
        let jitter = SIMD2<Double>(rng.randomDouble(in: -0.4...0.4), rng.randomDouble(in: -0.4...0.4))
        let startPos = entrance + jitter

        let remainingVisitors = max(1, settings.totalVisitors - metrics.arrivals)
        let maxGroup = min(remainingVisitors, max(1, settings.maxGroupSize))
        let partySize = persona == "family"
            ? rng.randomInt(in: min(2, maxGroup)...maxGroup)
            : rng.randomInt(in: 1...min(2, maxGroup))
        let speed = persona == "family" ? rng.randomDouble(in: 0.8...1.0) : rng.randomDouble(in: 0.95...1.3)
        let maxStops = persona == "buyer" ? 2 : 5
        let plannedStops = rng.randomInt(in: 1...max(1, min(maxStops, booths.count)))

        var visitor = SimulatedVisitor(
            id: nextVisitorID,
            persona: persona,
            position: navGrid.isWalkable(startPos) ? startPos : navGrid.nearestWalkablePoint(to: entrance),
            partySize: partySize,
            plannedStops: plannedStops,
            speed: speed
        )
        nextVisitorID += 1
        assignNextDestination(&visitor)
        return visitor
    }

    private func pickWeightedPersona() -> String {
        let options: [(String, Double)] = [
            ("social", max(0, settings.socializerWeight)),
            ("family", max(0, settings.familyWeight)),
            ("stroller", max(0, settings.strollerWeight)),
            ("buyer", max(0, settings.buyerWeight))
        ]
        let total = options.reduce(0.0) { $0 + $1.1 }
        guard total > 0 else { return "social" }
        var roll = rng.nextDouble() * total
        for (name, weight) in options {
            roll -= weight
            if roll <= 0 { return name }
        }
        return "social"
    }
}

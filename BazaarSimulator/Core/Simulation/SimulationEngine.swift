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
    func runWithRecordedFootage(durationMinutes: Int, frameIntervalSeconds: Double) async -> SimulationResult
}

/// Runs the crowd model on one layout with a fixed step, and turns it into visitors, metrics and heatmaps.
final class SimulationEngine: SimulationEngineProtocol {
    var visitors: [SimulatedVisitor] = []
    var metrics = SimulationMetrics()
    var densityCells: [DensityCell] = []
    var isRunning = false

    let layout: Layout
    let legend: Legend
    var settings: SimulationSettings

    var peakCellsByID: [Int: DensityCell] = [:]
    var smoothedDensity: [Double] = []
    var occupiedDensityUpdates = 0

    // Building the world is the expensive part, and a saved run never needs it.
    private lazy var world = CrowdWorld(layout: layout, legend: legend)
    private var crowd: CrowdSimulation?
    private var accumulatedTime = 0.0
    private var nextDensityUpdate = 0.0
    private static let stepsBetweenYields = 256

    init(layout: Layout, settings: SimulationSettings = SimulationSettings(), legend: Legend = Legend()) {
        self.layout = layout
        self.settings = settings
        self.legend = legend
    }

    // MARK: - Playback Controls

    func start() { isRunning = true }
    func pause() { isRunning = false }
    func toggleRunning() { isRunning.toggle() }

    func reset() {
        isRunning = false
        crowd = nil
        visitors = []
        metrics = SimulationMetrics()
        densityCells = []
        peakCellsByID = [:]
        smoothedDensity = []
        occupiedDensityUpdates = 0
        accumulatedTime = 0.0
        nextDensityUpdate = 0.0
    }

    func advance(realSeconds: Double, speed: Double) {
        guard realSeconds > 0 else { return }
        accumulatedTime += min(realSeconds, 0.5) * max(0.5, speed)

        var stepsTaken = 0
        while accumulatedTime >= CrowdParameters.stepSeconds && stepsTaken < 240 {
            step()
            accumulatedTime -= CrowdParameters.stepSeconds
            stepsTaken += 1
        }
        publishCrowdState()
    }

    func fastForward(minutes: Int) {
        for _ in 0..<max(0, minutes * 60 * CrowdParameters.stepsPerSecond) {
            step()
        }
        publishCrowdState()
    }

    /// Runs a full event and saves heatmap cells and footage frames.
    /// Yields regularly so the window stays responsive, and stops early when its task is cancelled.
    func runWithRecordedFootage(
        durationMinutes: Int = 0,
        frameIntervalSeconds: Double = 5.0
    ) async -> SimulationResult {
        reset()
        let targetMinutes = durationMinutes > 0 ? durationMinutes : max(1, settings.durationMinutes)
        let totalSteps = targetMinutes * 60 * CrowdParameters.stepsPerSecond
        let stepsPerFrame = max(1, Int(frameIntervalSeconds * Double(CrowdParameters.stepsPerSecond)))
        // Frames between heatmap refreshes share one array, which keeps an 11-hour recording small.
        let stepsPerHeatmap = 30 * CrowdParameters.stepsPerSecond
        var recordedHeatmap: [DensityCell] = []
        var frames: [SimulationFrame] = []

        for stepIndex in 1...totalSteps {
            step()
            if stepIndex == 1 || stepIndex % stepsPerFrame == 0 || stepIndex == totalSteps {
                publishCrowdState()
                if stepIndex % stepsPerHeatmap < stepsPerFrame || stepIndex == totalSteps {
                    recordedHeatmap = densityCells
                }
                frames.append(
                    SimulationFrame(
                        elapsedSeconds: metrics.elapsedSeconds,
                        visitors: visitors,
                        densityCells: recordedHeatmap,
                        metrics: metrics
                    )
                )
            }
            if stepIndex % Self.stepsBetweenYields == 0 {
                await Task.yield()
                if Task.isCancelled { break }
            }
        }

        return SimulationResult(
            layoutID: layout.id,
            layoutName: layout.name,
            durationSeconds: Double(targetMinutes * 60),
            startMinutesFromMidnight: settings.startMinutesFromMidnight,
            metrics: metrics,
            densityCells: peakCellsByID.values.sorted { $0.id < $1.id },
            frames: frames
        )
    }

    // MARK: - Simulation Step

    private func step() {
        let simulation = crowd ?? CrowdSimulation(world: world, settings: settings)
        crowd = simulation
        simulation.step()
        metrics.elapsedSeconds = simulation.time

        if metrics.elapsedSeconds >= nextDensityUpdate {
            publishCrowdState()
            updateDensityCells()
            nextDensityUpdate = metrics.elapsedSeconds + 1.0
        }
    }

    private func publishCrowdState() {
        guard let crowd else { return }
        visitors = crowd.snapshots()
        metrics.arrivals = crowd.stats.enteredPeople
        metrics.departed = crowd.stats.departedPeople
        metrics.peopleInside = crowd.peopleInside
        metrics.totalVisits = crowd.stats.visits
        metrics.queueBalks = crowd.stats.balks
        if crowd.stats.departedPeople > 0 {
            metrics.averageStaySeconds = crowd.stats.staySeconds / Double(crowd.stats.departedPeople)
        }
    }
}

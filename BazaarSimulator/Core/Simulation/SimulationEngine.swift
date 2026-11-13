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

    // Building the world is the expensive part, and a saved run never needs it.
    private lazy var world = CrowdWorld(layout: layout, legend: legend)
    private var crowd: CrowdSimulation?
    private var heatmap: CrowdHeatmap
    private var accumulatedTime = 0.0
    private var nextDensityUpdate = 0.0

    init(layout: Layout, settings: SimulationSettings = SimulationSettings(), legend: Legend = Legend()) {
        self.layout = layout
        self.settings = settings
        self.legend = legend
        heatmap = CrowdHeatmap(sizeM: layout.sizeM)
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
        heatmap = CrowdHeatmap(sizeM: layout.sizeM)
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

    /// Runs a full event away from the main thread and saves heatmap cells and footage frames.
    /// Cancelling the calling task stops the run early.
    func runWithRecordedFootage(
        durationMinutes: Int = 0,
        frameIntervalSeconds: Double = CrowdParameters.defaultFrameIntervalSeconds
    ) async -> SimulationResult {
        reset()
        let job = CrowdRecordingJob(
            world: world,
            settings: settings,
            layoutID: layout.id,
            layoutName: layout.name,
            sizeM: layout.sizeM,
            durationMinutes: durationMinutes > 0 ? durationMinutes : max(1, settings.durationMinutes),
            frameIntervalSeconds: frameIntervalSeconds
        )
        let task = Task.detached(priority: .userInitiated) { job.run() }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
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
            nextDensityUpdate = metrics.elapsedSeconds + CrowdParameters.liveDensityUpdateIntervalSeconds
        }
    }

    func updateDensityCells() {
        heatmap.update(with: visitors)
        densityCells = heatmap.cells
        metrics.meanDensity = heatmap.meanDensity
        metrics.peakDensity = heatmap.peakDensity
    }

    private func publishCrowdState() {
        guard let crowd else { return }
        visitors = crowd.snapshots()
        crowd.copyCounts(into: &metrics)
    }
}

/// One full recorded event, safe to run off the main thread because it owns its simulation.
private nonisolated struct CrowdRecordingJob: Sendable {
    let world: CrowdWorld
    let settings: SimulationSettings
    let layoutID: UUID
    let layoutName: String
    let sizeM: SIMD2<Double>
    let durationMinutes: Int
    let frameIntervalSeconds: Double

    func run() -> SimulationResult {
        let crowd = CrowdSimulation(world: world, settings: settings)
        var heatmap = CrowdHeatmap(sizeM: sizeM, totalVisitors: settings.totalVisitors)
        var metrics = SimulationMetrics()
        var frames: [SimulationFrame] = []

        let stepsPerSecond = CrowdParameters.stepsPerSecond
        let totalSteps = durationMinutes * 60 * stepsPerSecond
        let stepsPerFrame = max(1, Int(frameIntervalSeconds * Double(stepsPerSecond)))
        frames.reserveCapacity(totalSteps / stepsPerFrame + 2)

        for stepIndex in 1...totalSteps {
            crowd.step()

            if stepIndex == 1 || stepIndex % stepsPerFrame == 0 || stepIndex == totalSteps {
                heatmap.update(withAgents: crowd.agents)
                metrics.elapsedSeconds = crowd.time
                crowd.copyCounts(into: &metrics)
                metrics.meanDensity = heatmap.meanDensity
                metrics.peakDensity = heatmap.peakDensity
                frames.append(SimulationFrame(
                    elapsedSeconds: metrics.elapsedSeconds,
                    visitors: crowd.snapshots(),
                    densityCells: heatmap.cells,
                    metrics: metrics
                ))
            }
            if stepIndex % 256 == 0 && Task.isCancelled { break }
        }

        let summaryCells = heatmap.finalSummaryCells()
        metrics.peakDensity = heatmap.summaryPeakDensity

        return SimulationResult(
            layoutID: layoutID,
            layoutName: layoutName,
            durationSeconds: Double(durationMinutes * 60),
            startMinutesFromMidnight: settings.startMinutesFromMidnight,
            metrics: metrics,
            densityCells: summaryCells,
            frames: frames
        )
    }
}

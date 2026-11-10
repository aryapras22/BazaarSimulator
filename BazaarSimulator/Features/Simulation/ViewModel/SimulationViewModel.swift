import Foundation
import Observation

/// ViewModel that connects the 3D SimulationView to either saved simulation footage or a live SimulationEngine.
@Observable
@MainActor
final class SimulationViewModel {
    private(set) var layout: Layout
    let availableLayouts: [Layout]
    private var engine: any SimulationEngineProtocol
    private let onLayoutSelected: ((UUID) -> Void)?
    private let resultProvider: ((UUID) -> SimulationResult?)?

    private(set) var visitors: [SimulatedVisitor] = []
    private(set) var metrics = SimulationMetrics()
    private(set) var densityCells: [DensityCell] = []
    private(set) var isRunning = false

    private(set) var recordedFrames: [SimulationFrame] = []
    private(set) var currentFrameIndex: Int = 0
    private(set) var totalDurationSeconds: Double = 39_600
    private(set) var startMinutesFromMidnight: Int = 600
    private var isPlayingRecordedFootage = false
    private var playbackAccumulator: Double = 0

    var speedMultiplier: Double = 5.0
    var showHeatmap = true

    init(
        layout: Layout,
        availableLayouts: [Layout] = [],
        savedResult: SimulationResult? = nil,
        engine: (any SimulationEngineProtocol)? = nil,
        onLayoutSelected: ((UUID) -> Void)? = nil,
        resultProvider: ((UUID) -> SimulationResult?)? = nil
    ) {
        self.layout = layout
        self.availableLayouts = availableLayouts.isEmpty ? [layout] : availableLayouts
        self.engine = engine ?? SimulationEngine(layout: layout)
        self.onLayoutSelected = onLayoutSelected
        self.resultProvider = resultProvider

        if let savedResult, !savedResult.frames.isEmpty {
            loadSavedResult(savedResult)
        } else {
            syncStateFromEngine()
        }
    }

    var hasRecordedFootage: Bool {
        !recordedFrames.isEmpty
    }

    var totalFrames: Int {
        recordedFrames.count
    }

    var clockString: String {
        formatDuration(metrics.elapsedSeconds)
    }

    var totalDurationString: String {
        formatDuration(totalDurationSeconds)
    }

    var timeOfDayString: String {
        let elapsedMinutes = Int((metrics.elapsedSeconds / 60.0).rounded())
        let totalMinutes = (startMinutesFromMidnight + elapsedMinutes) % (24 * 60)
        return String(format: "%02d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    private func formatDuration(_ secondsValue: Double) -> String {
        let totalSeconds = max(0, Int(secondsValue.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func selectLayout(_ newLayout: Layout) {
        guard newLayout.id != layout.id else { return }
        layout = newLayout
        engine = SimulationEngine(layout: newLayout)
        if let saved = resultProvider?(newLayout.id), !saved.frames.isEmpty {
            loadSavedResult(saved)
        } else {
            recordedFrames = []
            isPlayingRecordedFootage = false
            syncStateFromEngine()
        }
        onLayoutSelected?(newLayout.id)
    }

    func seekToFrame(_ index: Int) {
        guard !recordedFrames.isEmpty else { return }
        let clamped = min(max(0, index), recordedFrames.count - 1)
        currentFrameIndex = clamped
        applyFrame(recordedFrames[clamped])
    }

    func togglePlay() {
        if hasRecordedFootage && isPlayingRecordedFootage {
            isRunning.toggle()
            if isRunning && currentFrameIndex >= recordedFrames.count - 1 {
                currentFrameIndex = 0
                applyFrame(recordedFrames[0])
            }
            return
        }
        engine.toggleRunning()
        syncStateFromEngine()
    }

    func play() {
        if hasRecordedFootage && isPlayingRecordedFootage {
            isRunning = true
            return
        }
        engine.start()
        syncStateFromEngine()
    }

    func pause() {
        if hasRecordedFootage && isPlayingRecordedFootage {
            isRunning = false
            return
        }
        engine.pause()
        syncStateFromEngine()
    }

    func reset() {
        if hasRecordedFootage {
            isRunning = false
            isPlayingRecordedFootage = true
            currentFrameIndex = 0
            applyFrame(recordedFrames[0])
            return
        }
        engine.reset()
        syncStateFromEngine()
    }

    func rerunLive() {
        isPlayingRecordedFootage = false
        engine.reset()
        engine.start()
        syncStateFromEngine()
    }

    func fastForward(minutes: Int) {
        if hasRecordedFootage && isPlayingRecordedFootage {
            let targetElapsed = metrics.elapsedSeconds + Double(minutes * 60)
            if let nextIdx = recordedFrames.firstIndex(where: { $0.elapsedSeconds >= targetElapsed }) {
                seekToFrame(nextIdx)
            } else {
                seekToFrame(recordedFrames.count - 1)
            }
            return
        }
        engine.fastForward(minutes: minutes)
        syncStateFromEngine()
    }

    func tick(realSeconds: Double) {
        if hasRecordedFootage && isPlayingRecordedFootage {
            guard isRunning else { return }
            playbackAccumulator += realSeconds * max(1.0, speedMultiplier / 2.5)
            if playbackAccumulator >= 0.12 {
                playbackAccumulator = 0
                if currentFrameIndex + 1 < recordedFrames.count {
                    currentFrameIndex += 1
                    applyFrame(recordedFrames[currentFrameIndex])
                } else {
                    isRunning = false
                }
            }
            return
        }

        guard engine.isRunning else { return }
        engine.advance(realSeconds: realSeconds, speed: speedMultiplier)
        syncStateFromEngine()
    }

    private func loadSavedResult(_ result: SimulationResult) {
        recordedFrames = result.frames
        totalDurationSeconds = max(result.durationSeconds, result.frames.last?.elapsedSeconds ?? 0)
        startMinutesFromMidnight = result.startMinutesFromMidnight
        isPlayingRecordedFootage = true
        isRunning = true
        currentFrameIndex = 0
        if let first = result.frames.first {
            applyFrame(first)
        }
    }

    private func applyFrame(_ frame: SimulationFrame) {
        visitors = frame.visitors
        metrics = frame.metrics
        densityCells = frame.densityCells
    }

    private func syncStateFromEngine() {
        visitors = engine.visitors
        metrics = engine.metrics
        densityCells = engine.densityCells
        isRunning = engine.isRunning
    }
}

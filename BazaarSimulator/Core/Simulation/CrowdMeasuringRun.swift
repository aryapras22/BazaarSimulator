import Foundation
import simd

/// Everything a measured run needs, as plain values, so the run can leave the main thread.
nonisolated struct CrowdMeasuringSetup: Sendable {
    let world: CrowdWorld
    let settings: SimulationSettings
    /// How long the event is open, in seconds.
    let openSeconds: Double
    /// For each minute the event is open, how its arrival rate compares to the day's average.
    let arrivalFactors: [Double]
    /// The measuring grid: where it starts, its size, which cells are floor, and which door each cell is in.
    let origin: SIMD2<Double>
    let cellSizeM: Double
    let columns: Int
    let rows: Int
    let walkable: [Bool]
    let doorIndex: [Int16]
    /// Which doors count toward the flow. When none does, people are counted as they enter and leave.
    let countsDoor: [Bool]
    /// The busiest window, in seconds after the event opens, kept as frames for playback.
    let window: ClosedRange<Double>?
    /// The visitor type each persona of the crowd model is shown as.
    let typeIndexByPersona: [String: Int]
}

nonisolated struct MeasuredVisitor: Sendable {
    let id: Int
    let position: SIMD2<Float>
    let typeIndex: Int
    let people: Int
    let isSeated: Bool
}

nonisolated struct MeasuredFrame: Sendable {
    let visitors: [MeasuredVisitor]
    let footfall: [UInt16]
}

/// What a run measured, before it is turned into a `LayoutAnalysis`.
nonisolated struct CrowdMeasurements: Sendable {
    var blockColumns = 0
    var blockCount = 0
    var blockArea: [Double] = []
    /// People in each block, one row of `blockCount` values per sample.
    var blockSamples: [Float] = []
    var flowPerMinute: [Double] = []
    var frames: [MeasuredFrame] = []
    var tileColumns = 0
    var tileCount = 0
    var enteredPeople = 0
}

/// Runs the crowd model through one whole event and measures it on the way: how many people stand in
/// each block of floor, how many pass the doors, and where everyone is through the busiest window.
nonisolated final class CrowdMeasuringRun {
    static let sampleIntervalSeconds = 10
    static let frameIntervalSeconds = 10
    static let blockCells = 6
    static let tileCells = 3
    /// Doors and floor tiles are checked this often, so a walking visitor cannot skip a cell.
    private static let trackEverySteps = 2
    /// Visitors still inside this long after closing are left there.
    private static let closingGraceSeconds = 1800.0

    private let setup: CrowdMeasuringSetup
    private let crowd: CrowdSimulation
    private let baseArrivalRate: Double
    private let hasCountedDoors: Bool
    private var stepIndex = 0
    private var result = CrowdMeasurements()
    private var tileFootfall: [UInt16]
    private var lastTile: [Int: Int] = [:]
    private var nextTileScratch: [Int: Int] = [:]
    private var inDoor: Set<Int> = []
    private var nextDoorScratch: Set<Int> = []
    private var countedPeople = 0

    init(setup: CrowdMeasuringSetup) {
        self.setup = setup
        crowd = CrowdSimulation(world: setup.world, settings: setup.settings)
        baseArrivalRate = crowd.arrivalRatePerSecond
        hasCountedDoors = setup.countsDoor.contains(true)

        result.blockColumns = (setup.columns + Self.blockCells - 1) / Self.blockCells
        result.blockCount = result.blockColumns * ((setup.rows + Self.blockCells - 1) / Self.blockCells)
        result.blockArea = Array(repeating: 0, count: result.blockCount)
        for cell in setup.walkable.indices where setup.walkable[cell] {
            result.blockArea[Self.group(of: cell, by: Self.blockCells, columns: setup.columns)]
                += setup.cellSizeM * setup.cellSizeM
        }
        result.tileColumns = (setup.columns + Self.tileCells - 1) / Self.tileCells
        result.tileCount = result.tileColumns * ((setup.rows + Self.tileCells - 1) / Self.tileCells)
        tileFootfall = Array(repeating: 0, count: result.tileCount)
        result.flowPerMinute = Array(repeating: 0, count: setup.arrivalFactors.count + 1)
    }

    var isFinished: Bool {
        // A layout with no way in has nothing to simulate.
        if setup.world.gates.isEmpty { return true }
        if crowd.time >= setup.openSeconds + Self.closingGraceSeconds { return true }
        return crowd.time > setup.openSeconds && crowd.agents.isEmpty
    }

    /// Runs to the end of the event, or until `isCancelled` says to stop.
    func run(
        onLiveFrame: (@Sendable ([MeasuredVisitor], Double) -> Void)? = nil,
        isCancelled: () -> Bool
    ) -> CrowdMeasurements {
        let liveStepStride = max(1, 20 * CrowdParameters.stepsPerSecond)
        let totalSeconds = max(1.0, setup.openSeconds)
        while !isFinished {
            for _ in 0..<256 where !isFinished {
                step()
                if let onLiveFrame, stepIndex % liveStepStride == 0 {
                    let progress = min(1.0, max(0.0, crowd.time / totalSeconds))
                    onLiveFrame(currentMeasuredVisitors(), progress)
                }
            }
            if isCancelled() { break }
        }
        result.enteredPeople = crowd.stats.enteredPeople
        return result
    }

    private func step() {
        let stepsPerSecond = CrowdParameters.stepsPerSecond
        if stepIndex % (60 * stepsPerSecond) == 0 {
            // Arrivals follow the day's peaks, and stop when the event closes.
            let minute = stepIndex / (60 * stepsPerSecond)
            crowd.arrivalRatePerSecond = minute < setup.arrivalFactors.count ? baseArrivalRate * setup.arrivalFactors[minute] : 0
        }
        // Measured before the step, so sample 0 and frame 0 are the moment the event or the window opens.
        let now = crowd.time
        let isRecording = setup.window?.contains(now) ?? false
        if stepIndex % (Self.sampleIntervalSeconds * stepsPerSecond) == 0, now < setup.openSeconds { sampleBlocks() }
        if isRecording, stepIndex % (Self.frameIntervalSeconds * stepsPerSecond) == 0 { recordFrame() }
        if stepIndex % Self.trackEverySteps == 0 { track(now: now, isRecording: isRecording) }
        crowd.step()
        stepIndex += 1
    }

    private static func group(of cell: Int, by size: Int, columns: Int) -> Int {
        (cell / columns / size) * ((columns + size - 1) / size) + (cell % columns) / size
    }

    private func cell(at position: SIMD2<Double>) -> Int? {
        let column = Int(((position.x - setup.origin.x) / setup.cellSizeM).rounded(.down))
        let row = Int(((position.y - setup.origin.y) / setup.cellSizeM).rounded(.down))
        guard column >= 0, column < setup.columns, row >= 0, row < setup.rows else { return nil }
        return row * setup.columns + column
    }

    /// Counts people through the doors, and walks into a new tile of floor while the window is open.
    private func track(now: Double, isRecording: Bool) {
        var passed = 0.0
        if isRecording || hasCountedDoors {
            if isRecording {
                nextTileScratch.removeAll(keepingCapacity: true)
            }
            if hasCountedDoors {
                nextDoorScratch.removeAll(keepingCapacity: true)
            }
            for agent in crowd.agents {
                guard let cell = cell(at: agent.position) else { continue }
                if isRecording {
                    let tile = Self.group(of: cell, by: Self.tileCells, columns: setup.columns)
                    if lastTile[agent.id] != tile, !agent.isSeated {
                        tileFootfall[tile] = UInt16(min(Int(tileFootfall[tile]) + Int(agent.weight), Int(UInt16.max)))
                    }
                    nextTileScratch[agent.id] = tile
                }
                if hasCountedDoors {
                    let door = Int(setup.doorIndex[cell])
                    if door >= 0, setup.countsDoor[door] {
                        if !inDoor.contains(agent.id) { passed += agent.weight }
                        nextDoorScratch.insert(agent.id)
                    }
                }
            }
            if isRecording {
                swap(&lastTile, &nextTileScratch)
            }
            if hasCountedDoors {
                swap(&inDoor, &nextDoorScratch)
            }
        }
        if !hasCountedDoors {
            let counted = crowd.stats.enteredPeople + crowd.stats.departedPeople
            passed = Double(counted - countedPeople)
            countedPeople = counted
        }
        let minute = Int(now / 60)
        if passed > 0, minute < result.flowPerMinute.count { result.flowPerMinute[minute] += passed }
    }

    private func sampleBlocks() {
        var counts = Array(repeating: Float(0), count: result.blockCount)
        for agent in crowd.agents {
            guard let cell = cell(at: agent.position) else { continue }
            counts[Self.group(of: cell, by: Self.blockCells, columns: setup.columns)] += Float(agent.weight)
        }
        result.blockSamples.append(contentsOf: counts)
    }

    private func recordFrame() {
        result.frames.append(MeasuredFrame(
            visitors: currentMeasuredVisitors(),
            footfall: tileFootfall
        ))
    }

    private func currentMeasuredVisitors() -> [MeasuredVisitor] {
        crowd.agents.map { agent in
            MeasuredVisitor(
                id: agent.id,
                position: SIMD2(Float(agent.position.x), Float(agent.position.y)),
                typeIndex: setup.typeIndexByPersona[agent.party.persona.key] ?? 0,
                people: Int(agent.weight),
                isSeated: agent.isSeated
            )
        }
    }
}

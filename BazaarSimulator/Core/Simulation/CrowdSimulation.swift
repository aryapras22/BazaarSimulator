import Foundation
import simd

/// A seeded, fixed-step crowd simulation of one layout over one event.
///
/// Visitors arrive in groups at the entrance, walk to a few booths, stay a while, and leave. Each
/// group walks the shortest way through the layout and slows down as its patch of floor fills up, so
/// crowding comes out of the layout and the parameters instead of being typed in. The same input and
/// seed always give the same result.
final class CrowdSimulation {
    static let stepSeconds = 2.0
    static let sampleEverySteps = 5
    static let maxSimulatedPeople = 30_000
    private static let blockCells = 6
    private static let closingGraceSeconds = 2.0 * 3600

    private enum Phase { case toBooth, dwelling, leaving }

    private struct Agent {
        let id: Int
        var position: SIMD2<Double>
        var cell: Int
        var phase: Phase
        var booth: Int
        var stopsLeft: Int
        var speedMps: Double
        var dwellSeconds: Double
        var dwellUntil: Double
        var people: Double
        var isInCountingDoor: Bool
        var typeIndex: Int
        var tile: Int
        var isDone = false
    }

    private let input: SimulationInput
    private let grid: NavigationGrid
    private var generator: SeededGenerator

    private let spawnCells: [Int]
    private let exitFields: [[Int32]]
    private let booths: [[Int]]
    private let reachableBooths: [Int]
    private var boothFields: [[Int32]?]
    private let countsDoor: [Bool]
    private let countsSpawnAndExit: Bool

    private let arrivals: [Arrival]
    private let peopleScale: Double
    private let openSeconds: Double
    private var nextArrival = 0
    private var agents: [Agent] = []
    private var now = 0.0
    private var stepIndex = 0

    private let blockColumns: Int
    private let blockCount: Int
    private let blockArea: [Double]
    private var blockDensityNow: [Double]
    private var blockSamples: [Float] = []
    private var flowPerMinute: [Double]

    // The busiest window, kept as frames for playback.
    private static let tileCells = 3
    private static let frameIntervalSeconds = 6
    private let replayWindow: ClosedRange<Double>?
    private let tileColumns: Int
    private let tileCount: Int
    private var tileFootfall: [UInt16]
    private var replayFrames: [SimulationReplay.Frame] = []
    private var isRecordingWindow = false

    init(input: SimulationInput) {
        self.input = input
        let grid = NavigationGrid(layout: input.layout)
        self.grid = grid
        generator = SeededGenerator(seed: input.seed)
        openSeconds = Double(input.parameters.eventHours.durationMinutes) * 60

        // Doors, entrance, and exit.
        let layout = input.layout
        let doors = grid.doors
        let points = Self.entryPoints(layout: layout, grid: grid)
        spawnCells = points.spawn
        let exitCells = points.exits
        exitFields = exitCells.map { grid.distanceField(from: [$0]) }

        let hallDoors = doors.map { $0.flow?.connection == .hallToLobby }
        countsSpawnAndExit = !hallDoors.contains(true)
        countsDoor = countsSpawnAndExit ? Array(repeating: false, count: doors.count) : hallDoors

        // Booths a visitor can reach from the entrance.
        let entranceField = spawnCells.first.map { grid.distanceField(from: [$0]) } ?? []
        let boothCells = layout.objects.filter { $0.kind == .booth }.map { grid.accessCells(of: $0) }
        booths = boothCells
        reachableBooths = boothCells.indices.filter { index in
            !entranceField.isEmpty && boothCells[index].contains { entranceField[$0] != Int32.max }
        }
        boothFields = Array(repeating: nil, count: boothCells.count)

        // Floor blocks for measuring density.
        blockColumns = (grid.columns + Self.blockCells - 1) / Self.blockCells
        let blockRows = (grid.rows + Self.blockCells - 1) / Self.blockCells
        blockCount = blockColumns * blockRows
        var area = Array(repeating: 0.0, count: blockCount)
        for cell in 0..<grid.cellCount where grid.walkable[cell] {
            area[Self.block(of: cell, columns: grid.columns, blockColumns: blockColumns)]
                += NavigationGrid.cellSizeM * NavigationGrid.cellSizeM
        }
        blockArea = area
        blockDensityNow = Array(repeating: 0, count: blockCount)
        flowPerMinute = Array(repeating: 0, count: input.parameters.eventHours.durationMinutes + 1)

        // The busiest window, as seconds after the event opens.
        if let focus = input.focus, focus.durationMinutes > 0 {
            let start = Double(focus.startMinute - input.parameters.eventHours.startMinute) * 60
            replayWindow = start...(start + Double(focus.durationMinutes) * 60)
        } else {
            replayWindow = nil
        }
        tileColumns = (grid.columns + Self.tileCells - 1) / Self.tileCells
        tileCount = tileColumns * ((grid.rows + Self.tileCells - 1) / Self.tileCells)
        tileFootfall = Array(repeating: 0, count: tileCount)

        // Arrivals, with a cap on how many people are simulated one by one.
        let total = max(input.parameters.totalVisitors, 0)
        let simulated = min(total, Self.maxSimulatedPeople)
        peopleScale = simulated > 0 ? Double(total) / Double(simulated) : 1
        arrivals = spawnCells.isEmpty ? [] : SpawnScheduler.arrivals(
            parameters: input.parameters,
            visitorTypes: input.visitorTypes,
            simulatedPeople: simulated,
            generator: &generator
        )
    }

    var isFinished: Bool {
        if now >= openSeconds + Self.closingGraceSeconds { return true }
        return nextArrival >= arrivals.count && agents.isEmpty && now >= openSeconds
    }

    /// Runs the whole event and returns what was measured.
    func runToEnd() -> LayoutAnalysis {
        while !isFinished { advance(steps: 500) }
        return makeAnalysis()
    }

    func advance(steps: Int) {
        for _ in 0..<steps where !isFinished {
            stepOnce()
        }
    }

    /// Where visitors come in and where they leave: the layout's spawn and exit markers, else its
    /// outside doors, else any door that allows it.
    private static func entryPoints(layout: Layout, grid: NavigationGrid) -> (spawn: [Int], exits: [Int]) {
        func cells(of kind: LayoutMarkerKind) -> [Int] {
            layout.markers.filter { $0.kind == kind }.compactMap { grid.nearestWalkableCell(to: $0.position) }
        }
        func cells(doorsWhere test: (NavigationGrid.Door) -> Bool) -> [Int] {
            grid.doors.filter(test).compactMap { grid.nearestWalkableCell(to: $0.center) }
        }
        func isOutside(_ door: NavigationGrid.Door) -> Bool { door.flow?.connection == .lobbyToOutside }

        let spawn = cells(of: .spawn).nonEmpty
            ?? cells(doorsWhere: { isOutside($0) && ($0.flow?.direction.allowsEntry ?? false) }).nonEmpty
            ?? cells(doorsWhere: { $0.flow?.direction.allowsEntry ?? false }).nonEmpty
            ?? cells(doorsWhere: { _ in true })
        let exits = cells(of: .exit).nonEmpty
            ?? cells(doorsWhere: { isOutside($0) && ($0.flow?.direction.allowsExit ?? false) }).nonEmpty
            ?? cells(doorsWhere: { $0.flow?.direction.allowsExit ?? false }).nonEmpty
            ?? spawn
        return (spawn, exits)
    }

    // MARK: Stepping

    private func stepOnce() {
        while nextArrival < arrivals.count, arrivals[nextArrival].time <= now {
            spawn(arrivals[nextArrival])
            nextArrival += 1
        }
        if stepIndex % Self.sampleEverySteps == 0 {
            measureBlocks()
        }
        isRecordingWindow = replayWindow?.contains(now) ?? false
        if let window = replayWindow, isRecordingWindow, Int(now - window.lowerBound) % Self.frameIntervalSeconds == 0 {
            recordFrame()
        }
        for index in agents.indices {
            update(&agents[index])
        }
        agents.removeAll { $0.isDone }
        now += Self.stepSeconds
        stepIndex += 1
    }

    private func spawn(_ arrival: Arrival) {
        guard !spawnCells.isEmpty else { return }
        let type = input.visitorTypes[arrival.typeIndex]
        let cell = spawnCells[Int(generator.unit() * Double(spawnCells.count)) % spawnCells.count]
        var agent = Agent(
            id: nextArrival,
            position: grid.center(of: cell),
            cell: cell,
            phase: .toBooth,
            booth: -1,
            stopsLeft: max(type.plannedStops, 0),
            speedMps: max(type.walkingSpeedMps, 0.2),
            dwellSeconds: max(type.dwellMinutes, 0) * 60,
            dwellUntil: 0,
            people: Double(arrival.people) * peopleScale,
            isInCountingDoor: false,
            typeIndex: arrival.typeIndex,
            tile: Self.tile(of: cell, columns: grid.columns, tileColumns: tileColumns)
        )
        if countsSpawnAndExit { recordFlow(agent.people) }
        pickNextStop(&agent)
        noteDoor(&agent)
        agents.append(agent)
    }

    private func pickNextStop(_ agent: inout Agent) {
        if agent.stopsLeft > 0, !reachableBooths.isEmpty {
            agent.booth = reachableBooths[Int(generator.unit() * Double(reachableBooths.count)) % reachableBooths.count]
            agent.phase = .toBooth
        } else {
            agent.phase = .leaving
        }
    }

    private func update(_ agent: inout Agent) {
        switch agent.phase {
        case .toBooth:
            let field = boothField(agent.booth)
            move(&agent, along: field)
            if field[agent.cell] == 0 {
                agent.phase = .dwelling
                agent.dwellUntil = now + agent.dwellSeconds * (0.6 + 0.8 * generator.unit())
            }
        case .dwelling:
            guard now >= agent.dwellUntil else { return }
            agent.stopsLeft -= 1
            pickNextStop(&agent)
        case .leaving:
            guard let field = exitFields.min(by: { $0[agent.cell] < $1[agent.cell] }),
                  field[agent.cell] != Int32.max else {
                agent.isDone = true
                return
            }
            move(&agent, along: field)
            if field[agent.cell] == 0 {
                if countsSpawnAndExit { recordFlow(agent.people) }
                agent.isDone = true
            }
        }
    }

    /// Walks along the field for one step. Crowded floor slows the walk down.
    private func move(_ agent: inout Agent, along field: [Int32]) {
        let block = Self.block(of: agent.cell, columns: grid.columns, blockColumns: blockColumns)
        let density = blockArea[block] > 0 ? blockDensityNow[block] : 0
        let crowdFactor = max(1 / (1 + density * density), 0.1)
        var remaining = agent.speedMps * crowdFactor * Self.stepSeconds

        var guardCount = 0
        while remaining > 1e-9, guardCount < 64, field[agent.cell] != 0 {
            guardCount += 1
            guard let next = grid.nextCell(from: agent.cell, in: field) else { break }
            let target = grid.center(of: next)
            let delta = target - agent.position
            let length = simd_length(delta)
            if length <= remaining {
                agent.position = target
                agent.cell = next
                remaining -= length
                noteDoor(&agent)
                noteTile(&agent)
            } else {
                agent.position += delta / length * remaining
                remaining = 0
            }
        }
    }

    private func boothField(_ booth: Int) -> [Int32] {
        if let field = boothFields[booth] { return field }
        let field = grid.distanceField(from: booths[booth])
        boothFields[booth] = field
        return field
    }

    // MARK: Measuring

    private static func block(of cell: Int, columns: Int, blockColumns: Int) -> Int {
        (cell / columns / blockCells) * blockColumns + (cell % columns) / blockCells
    }

    private static func tile(of cell: Int, columns: Int, tileColumns: Int) -> Int {
        (cell / columns / tileCells) * tileColumns + (cell % columns) / tileCells
    }

    /// Counts a walk into a new tile of floor, while the busiest window is open.
    private func noteTile(_ agent: inout Agent) {
        let tile = Self.tile(of: agent.cell, columns: grid.columns, tileColumns: tileColumns)
        guard tile != agent.tile else { return }
        agent.tile = tile
        if isRecordingWindow {
            tileFootfall[tile] = UInt16(min(Int(tileFootfall[tile]) + Int(agent.people.rounded()), Int(UInt16.max)))
        }
    }

    private func recordFrame() {
        replayFrames.append(SimulationReplay.Frame(
            visitors: agents.map {
                ReplayVisitor(
                    id: $0.id,
                    position: SIMD2(Float($0.position.x), Float($0.position.y)),
                    typeIndex: $0.typeIndex,
                    people: Int($0.people.rounded())
                )
            },
            footfall: tileFootfall
        ))
    }

    private func noteDoor(_ agent: inout Agent) {
        let door = Int(grid.doorIndex[agent.cell])
        if door >= 0, countsDoor[door] {
            if !agent.isInCountingDoor { recordFlow(agent.people) }
            agent.isInCountingDoor = true
        } else {
            agent.isInCountingDoor = false
        }
    }

    private func recordFlow(_ people: Double) {
        let minute = Int(now / 60)
        guard minute < flowPerMinute.count else { return }
        flowPerMinute[minute] += people
    }

    private func measureBlocks() {
        var counts = Array(repeating: Float(0), count: blockCount)
        for agent in agents {
            counts[Self.block(of: agent.cell, columns: grid.columns, blockColumns: blockColumns)] += Float(agent.people)
        }
        for block in 0..<blockCount {
            blockDensityNow[block] = blockArea[block] > 0 ? Double(counts[block]) / blockArea[block] : 0
        }
        if now < openSeconds {
            blockSamples.append(contentsOf: counts)
        }
    }

    // MARK: Result

    func makeAnalysis() -> LayoutAnalysis {
        let sampleCount = blockSamples.count / max(blockCount, 1)
        let eventStart = input.parameters.eventHours.startMinute
        let intervalSeconds = Int(Self.stepSeconds) * Self.sampleEverySteps
        let samplesPerMinute = 60 / intervalSeconds

        let windowLow: Int
        let windowHigh: Int
        if let focus = input.focus {
            windowLow = min(max((focus.startMinute - eventStart) * samplesPerMinute, 0), max(sampleCount - 1, 0))
            windowHigh = min(windowLow + focus.durationMinutes * samplesPerMinute, max(sampleCount - 1, 0))
        } else {
            windowLow = 0
            windowHigh = max(sampleCount - 1, 0)
        }

        func density(_ block: Int, _ sample: Int) -> Double {
            Double(blockSamples[sample * blockCount + block]) / blockArea[block]
        }
        var candidates: [SpotSelector.Candidate] = []
        var windowPeaks = Array(repeating: 0.0, count: blockCount)
        var dayPeaks = Array(repeating: 0.0, count: blockCount)
        if sampleCount > 0 {
            for block in 0..<blockCount where blockArea[block] >= SpotSelector.minimumAreaM2 {
                candidates.append(SpotSelector.Candidate(block: block, areaM2: blockArea[block]))
                for sample in 0..<sampleCount {
                    let value = density(block, sample)
                    dayPeaks[block] = max(dayPeaks[block], value)
                    if sample >= windowLow, sample <= windowHigh {
                        windowPeaks[block] = max(windowPeaks[block], value)
                    }
                }
            }
        }
        let centers = (0..<blockCount).map { blockCenter($0) }
        let chosen = SpotSelector.select(
            candidates: candidates, peaks: windowPeaks, dayPeaks: dayPeaks, centers: centers
        )
        let names = SpotSelector.uniqueNames(chosen.map {
            SpotSelector.name(at: centers[$0], in: input.layout, grid: grid)
        })

        let spots = chosen.enumerated().map { offset, block in
            SpotMeasurement(
                number: offset + 1,
                name: names[offset],
                position: centers[block],
                densitySamples: (0..<sampleCount).map { Float(density(block, $0)) },
                peopleSamples: (0..<sampleCount).map { Int(blockSamples[$0 * blockCount + block].rounded()) }
            )
        }
        return LayoutAnalysis(
            layoutID: input.layout.id,
            eventStartMinute: eventStart,
            sampleIntervalSeconds: intervalSeconds,
            spots: spots,
            flowPerMinute: flowPerMinute,
            simulatedPeople: arrivals.reduce(0) { $0 + $1.people },
            totalPeople: max(input.parameters.totalVisitors, 0),
            plan: grid.plan,
            replay: replayFrames.isEmpty ? nil : SimulationReplay(
                startMinute: input.focus?.startMinute ?? eventStart,
                frameIntervalSeconds: Self.frameIntervalSeconds,
                frames: replayFrames,
                walkable: grid.walkableMask,
                footfallColumns: tileColumns,
                footfallRows: tileCount / max(tileColumns, 1),
                footfallTileM: Double(Self.tileCells) * NavigationGrid.cellSizeM
            )
        )
    }

    private func blockCenter(_ block: Int) -> SIMD2<Double> {
        let column = block % blockColumns
        let row = block / blockColumns
        let size = Double(Self.blockCells) * NavigationGrid.cellSizeM
        return SIMD2(
            grid.origin.x + (Double(column) + 0.5) * size,
            grid.origin.y + (Double(row) + 0.5) * size
        )
    }
}

private extension Array {
    /// Self if it has elements, else nil. Lets fallbacks chain with `??`.
    var nonEmpty: [Element]? { isEmpty ? nil : self }
}

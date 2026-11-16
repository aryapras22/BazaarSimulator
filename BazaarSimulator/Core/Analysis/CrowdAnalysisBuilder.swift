import Foundation
import simd

/// Prepares a measured run of the crowd model from the event's parameters, and turns what it measured
/// into the `LayoutAnalysis` the Analysis feature reads.
enum CrowdAnalysisBuilder {
    /// The visitor type each persona of the crowd model stands for, by the type's id.
    private static let personas = [("social", "socializer"), ("family", "family"), ("stroller", "stroller"), ("buyer", "buyer")]

    static func setup(for input: SimulationInput, grid: NavigationGrid) -> CrowdMeasuringSetup {
        let parameters = input.parameters
        let hours = parameters.eventHours
        let minutes = max(hours.durationMinutes, 1)

        // The same visitors over the same hours, arriving faster inside the peak periods.
        let weights = (0..<minutes).map { minute -> Double in
            let clock = hours.startMinute + minute
            let isPeak = parameters.peakPeriods.contains { clock >= $0.startMinute && clock < $0.endMinute }
            return isPeak ? SpawnScheduler.peakRateMultiplier : 1
        }
        let mean = weights.reduce(0, +) / Double(minutes)

        func share(_ typeID: String) -> Double {
            Double(max(parameters.mix.share(for: typeID)?.percent ?? 0, 0))
        }
        let total = max(parameters.totalVisitors, 0)
        let settings = SimulationSettings(
            totalVisitors: total,
            arrivalsPer15Min: Double(total) / (Double(minutes) / 15),
            durationMinutes: minutes,
            startMinutesFromMidnight: hours.startMinute,
            randomSeed: input.seed,
            socializerWeight: share("socializer"),
            familyWeight: share("family"),
            strollerWeight: share("stroller"),
            buyerWeight: share("buyer")
        )
        // A persona whose type the catalog does not have is shown as one of the types it does have.
        var typeIndex: [String: Int] = [:]
        for (offset, persona) in personas.enumerated() {
            typeIndex[persona.0] = input.visitorTypes.firstIndex { $0.id == persona.1 }
                ?? offset % max(input.visitorTypes.count, 1)
        }

        let openSeconds = Double(hours.durationMinutes) * 60
        let window: ClosedRange<Double>? = hours.durationMinutes > 0 ? 0...openSeconds : nil
        let hallDoors = grid.doors.map { $0.flow?.connection == .hallToLobby }
        return CrowdMeasuringSetup(
            world: CrowdWorld(layout: input.layout, legend: input.legend),
            settings: settings,
            openSeconds: openSeconds,
            arrivalFactors: weights.map { $0 / mean },
            origin: grid.origin,
            cellSizeM: NavigationGrid.cellSizeM,
            columns: grid.columns,
            rows: grid.rows,
            walkable: grid.walkable,
            doorIndex: grid.doorIndex,
            countsDoor: hallDoors,
            window: window,
            typeIndexByPersona: typeIndex
        )
    }

    static func analysis(for input: SimulationInput, grid: NavigationGrid, measured: CrowdMeasurements) -> LayoutAnalysis {
        let blockCount = measured.blockCount
        let sampleCount = measured.blockSamples.count / max(blockCount, 1)
        let eventStart = input.parameters.eventHours.startMinute
        let intervalSeconds = CrowdMeasuringRun.sampleIntervalSeconds
        let samplesPerMinute = 60 / intervalSeconds

        var windowLow = 0
        var windowHigh = max(sampleCount - 1, 0)
        if let focus = input.focus {
            windowLow = min(max((focus.startMinute - eventStart) * samplesPerMinute, 0), max(sampleCount - 1, 0))
            windowHigh = min(windowLow + focus.durationMinutes * samplesPerMinute, max(sampleCount - 1, 0))
        }
        func density(_ block: Int, _ sample: Int) -> Double {
            Double(measured.blockSamples[sample * blockCount + block]) / measured.blockArea[block]
        }
        var candidates: [SpotSelector.Candidate] = []
        var windowPeaks = Array(repeating: 0.0, count: blockCount)
        var dayPeaks = Array(repeating: 0.0, count: blockCount)
        if sampleCount > 0 {
            for block in 0..<blockCount where measured.blockArea[block] >= SpotSelector.minimumAreaM2 {
                candidates.append(SpotSelector.Candidate(block: block, areaM2: measured.blockArea[block]))
                for sample in 0..<sampleCount {
                    let value = density(block, sample)
                    dayPeaks[block] = max(dayPeaks[block], value)
                    if sample >= windowLow, sample <= windowHigh { windowPeaks[block] = max(windowPeaks[block], value) }
                }
            }
        }
        let blockSize = Double(CrowdMeasuringRun.blockCells) * NavigationGrid.cellSizeM
        let centers = (0..<blockCount).map { block in
            SIMD2(
                grid.origin.x + (Double(block % max(measured.blockColumns, 1)) + 0.5) * blockSize,
                grid.origin.y + (Double(block / max(measured.blockColumns, 1)) + 0.5) * blockSize
            )
        }
        let chosen = SpotSelector.select(candidates: candidates, peaks: windowPeaks, dayPeaks: dayPeaks, centers: centers)
        let names = SpotSelector.uniqueNames(chosen.map { SpotSelector.name(at: centers[$0], in: input.layout, grid: grid) })
        let spots = chosen.enumerated().map { offset, block in
            SpotMeasurement(
                number: offset + 1,
                name: names[offset],
                position: centers[block],
                densitySamples: (0..<sampleCount).map { Float(density(block, $0)) },
                peopleSamples: (0..<sampleCount).map { Int(measured.blockSamples[$0 * blockCount + block].rounded()) }
            )
        }
        return LayoutAnalysis(
            layoutID: input.layout.id,
            eventStartMinute: eventStart,
            sampleIntervalSeconds: intervalSeconds,
            spots: spots,
            flowPerMinute: measured.flowPerMinute,
            simulatedPeople: measured.enteredPeople,
            totalPeople: max(input.parameters.totalVisitors, 0),
            plan: grid.plan,
            replay: replay(for: input, grid: grid, measured: measured)
        )
    }

    private static func replay(for input: SimulationInput, grid: NavigationGrid, measured: CrowdMeasurements) -> SimulationReplay? {
        guard !measured.frames.isEmpty else { return nil }
        return SimulationReplay(
            startMinute: input.parameters.eventHours.startMinute,
            frameIntervalSeconds: CrowdMeasuringRun.frameIntervalSeconds,
            frames: measured.frames.map { frame in
                SimulationReplay.Frame(
                    visitors: frame.visitors.map {
                        ReplayVisitor(
                            id: $0.id, position: $0.position, typeIndex: $0.typeIndex, people: $0.people, isSeated: $0.isSeated
                        )
                    },
                    footfall: frame.footfall
                )
            },
            walkable: grid.walkableMask,
            footfallColumns: measured.tileColumns,
            footfallRows: measured.tileCount / max(measured.tileColumns, 1),
            footfallTileM: Double(CrowdMeasuringRun.tileCells) * NavigationGrid.cellSizeM
        )
    }
}

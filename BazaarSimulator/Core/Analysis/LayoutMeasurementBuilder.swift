import Foundation
import simd

/// Reads one finished run of the engine into the per-spot, per-minute measurements the Analysis page works from.
/// Spots are the most crowded places of the whole day, and each is sampled at every frame of the run.
enum LayoutMeasurementBuilder {
    static let sampleIntervalSeconds = 15
    static let spotLimit = 5
    private static let densityThreshold = 0.27

    static func build(
        result: SimulationResult,
        layout: Layout,
        parameters: EventParameters
    ) -> LayoutAnalysis {
        let frames = sampled(result.frames)
        let spotCells = busiestCells(in: result.frames)
        let spots = spotCells.enumerated().map { index, cell in
            let samples = frames.map { density(of: cell.id, in: $0) }
            return SpotMeasurement(
                number: index + 1,
                name: name(near: cell.center, in: layout),
                position: cell.center,
                densitySamples: samples.map(Float.init),
                peopleSamples: frames.map { people(near: cell.center, in: $0) }
            )
        }
        return LayoutAnalysis(
            layoutID: layout.id,
            eventStartMinute: result.startMinutesFromMidnight,
            sampleIntervalSeconds: sampleIntervalSeconds,
            spots: spots,
            flowPerMinute: flowPerMinute(in: result.frames),
            simulatedPeople: result.metrics.arrivals,
            totalPeople: parameters.totalVisitors,
            plan: PlanFrame(origin: .zero, size: layout.sizeM)
        )
    }

    /// The minute of the day with the most people inside, for the Analysis page's busiest window.
    static func busiestMinute(in result: SimulationResult) -> Int {
        let busiest = result.frames.max { $0.metrics.peopleInside < $1.metrics.peopleInside }
        let seconds = busiest?.elapsedSeconds ?? 0
        return result.startMinutesFromMidnight + Int(seconds / 60)
    }

    // MARK: - Spots

    /// People within this distance of a spot count as being at it.
    private static let spotRadiusM = 3.0

    /// The people the simulation had standing within reach of the spot at this frame.
    private static func people(near point: SIMD2<Double>, in frame: SimulationFrame) -> Int {
        frame.visitors.reduce(0) { total, visitor in
            simd_distance(visitor.position, point) <= spotRadiusM ? total + Int(visitor.peopleCount) : total
        }
    }

    private static func busiestCells(in frames: [SimulationFrame]) -> [DensityCell] {
        var peak: [Int: DensityCell] = [:]
        for cell in frames.lazy.flatMap(\.densityCells)
        where (peak[cell.id]?.peoplePerSquareMetre ?? 0) < cell.peoplePerSquareMetre {
            peak[cell.id] = cell
        }
        let findings = SimulationAnalysis.bottlenecks(from: Array(peak.values), limit: spotLimit)
        return findings.compactMap { finding in
            peak.values.first { $0.center == finding.point }
        }
    }

    private static func density(of cellID: Int, in frame: SimulationFrame) -> Double {
        frame.densityCells.first { $0.id == cellID }?.peoplePerSquareMetre ?? 0
    }

    /// The label of the closest booth, door, or table, so a spot reads as "Near B-7".
    private static func name(near point: SIMD2<Double>, in layout: Layout) -> String {
        let named = layout.objects.filter { !$0.label.isEmpty }
        guard let closest = named.min(by: {
            simd_distance($0.placement.center, point) < simd_distance($1.placement.center, point)
        }) else { return "(\(Int(point.x))m, \(Int(point.y))m)" }
        return "Near \(closest.label)"
    }

    // MARK: - Series

    private static func sampled(_ frames: [SimulationFrame]) -> [SimulationFrame] {
        guard frames.count > 1 else { return frames }
        let spacing = max(frames[1].elapsedSeconds - frames[0].elapsedSeconds, 1)
        let stride = max(Int((Double(sampleIntervalSeconds) / spacing).rounded()), 1)
        return Swift.stride(from: 0, to: frames.count, by: stride).map { frames[$0] }
    }

    /// People entering or leaving each minute, from the running totals at every frame.
    private static func flowPerMinute(in frames: [SimulationFrame]) -> [Double] {
        guard let last = frames.last else { return [] }
        let minutes = Int(last.elapsedSeconds / 60) + 1
        var totals = [Double](repeating: 0, count: minutes + 1)
        for frame in frames {
            let minute = min(Int(frame.elapsedSeconds / 60), minutes)
            totals[minute] = Double(frame.metrics.arrivals + frame.metrics.departed)
        }
        // Frames can skip a minute, so carry the last known total forward before taking differences.
        for index in 1..<totals.count where totals[index] < totals[index - 1] {
            totals[index] = totals[index - 1]
        }
        return (0..<minutes).map { totals[$0 + 1] - totals[$0] }
    }
}

import Foundation
import Observation
import SwiftUI

/// A visitor placed on the plan: where, as a share of the plan, and who.
struct DrawnVisitor {
    let id: Int
    let typeIndex: Int
    let point: CGPoint
    let people: Int
    var isSeated = false
}

/// Plays back the busiest window of one layout: visitors, crowd density, and the most walked paths.
@Observable
@MainActor
final class SimulationPlayerViewModel {
    /// At 1x speed, each real second advances 30 simulated seconds (2x = 60s/s, 4x = 120s/s).
    static let simulatedSecondsPerPlaybackSecond = 30.0
    /// Fallback playback duration before a replay loads (11 hours at 30 simulated seconds per second).
    static let defaultPlaybackSeconds = 39_600.0 / simulatedSecondsPerPlaybackSecond
    static let heatColumns = 36

    enum Phase: Equatable {
        case loading
        case needsLayouts
        case ready
    }

    let projectID: UUID
    let layoutID: LayoutID
    /// The saved run being played, or nil for the project as it is now.
    let analysisID: UUID?
    /// The two layouts to play, when they are not the pair of the run: a saved run showing another pair.
    let layoutIDs: [UUID]?
    private let session: any ProjectSessionProtocol
    private let analysisService: any AnalysisServiceProtocol
    private let catalog: PresetCatalog
    let onBack: () -> Void

    var mode: SimulationMode = .congestion
    var viewStyle: SimulationViewStyle = .twoD
    var hoveredSpot: Int?
    private(set) var phase: Phase = .loading
    private(set) var result: SimulationResult?
    private var cachedCoverage: [Double]?
    private var cachedWalkablePath: Path?
    @ObservationIgnored private var cachedVenue: SimulationVenue?

    init(
        projectID: UUID,
        layoutID: LayoutID,
        analysisID: UUID? = nil,
        layoutIDs: [UUID]? = nil,
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog,
        onBack: @escaping () -> Void = {}
    ) {
        self.projectID = projectID
        self.layoutID = layoutID
        self.analysisID = analysisID
        self.layoutIDs = layoutIDs
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
        self.onBack = onBack
    }

    func load() async {
        let saved = analysisID.flatMap { session.savedAnalysis(id: $0, in: projectID) }
        // A layout of the saved run is played as the run had it, and any other as the project has it now.
        let pair = layoutIDs?.compactMap { id in
            saved?.layouts.first { $0.id == id } ?? session.layout(id: id, in: projectID)
        }
        switch await SimulationLoader.load(
            projectID: projectID, savedAnalysis: saved, layouts: pair?.isEmpty == false ? pair : nil,
            session: session, analysisService: analysisService, catalog: catalog
        ) {
        case .needsLayouts:
            phase = .needsLayouts
        case .ready(let loaded):
            result = loaded
            cachedVenue = nil
            phase = loaded.replay(for: layoutID) == nil ? .needsLayouts : .ready
        case .cancelled:
            break
        }
    }

    // MARK: What is on screen

    var outcome: LayoutOutcome? { result?.outcomes[layoutID] }
    var layout: Layout? { result?.layouts[layoutID] }
    var legend: Legend { session.draft(for: projectID)?.legend ?? Legend() }
    var tenantTypes: [TenantLegendItem] { TenantColors.legendItems(for: layout, legend: legend) }
    var replay: SimulationReplay? { result?.replay(for: layoutID) }
    var visitorTypes: [VisitorType] { result?.visitorTypes ?? [] }
    var plan: PlanFrame { result?.analyses[layoutID]?.plan ?? .unit }
    var planAspect: CGFloat { CGFloat(plan.size.x / max(plan.size.y, 1)) }

    /// The window's title: the bazaar and the layout.
    var windowTitle: String {
        let name = session.projects.first { $0.id == projectID }?.name ?? "Project"
        return "\(name) · \(layoutID.name)"
    }

    var windowText: String {
        if let replay, replay.durationSeconds > 0 {
            let endMinute = replay.startMinute + Int((replay.durationSeconds / 60).rounded())
            return "\(TimeRange.format(replay.startMinute)) - \(TimeRange.format(endMinute))"
        }
        guard let window = result?.schedule.window else { return "" }
        return "\(TimeRange.format(window.startMinute)) - \(TimeRange.format(window.endMinute))"
    }

    /// Density of a numbered spot at `playback` seconds into the full-day replay.
    func spotDensity(for spot: SpotOutcome, at playback: Double) -> Double {
        if let analysis = result?.analyses[layoutID],
           let measured = analysis.spots.first(where: { $0.number == spot.number }),
           !measured.densitySamples.isEmpty {
            let step = windowSeconds(at: playback) / Double(max(analysis.sampleIntervalSeconds, 1))
            let low = min(max(Int(step.rounded(.down)), 0), measured.densitySamples.count - 1)
            let high = min(low + 1, measured.densitySamples.count - 1)
            let fraction = step - Double(low)
            return Double(measured.densitySamples[low]) * (1 - fraction) + Double(measured.densitySamples[high]) * fraction
        }
        return spot.density(at: progress(at: playback))
    }

    var heatRows: Int {
        max(Int((Double(Self.heatColumns) * plan.size.y / max(plan.size.x, 1)).rounded()), 1)
    }

    // MARK: Time

    /// Real-time seconds needed to play the full event at 1x speed (30 simulated seconds per real second).
    var playbackDuration: Double {
        guard let duration = replay?.durationSeconds, duration > 0 else {
            return Self.defaultPlaybackSeconds
        }
        return max(duration / Self.simulatedSecondsPerPlaybackSecond, 1.0)
    }

    /// How far through the window, 0 to 1, after `playback` seconds of playback.
    func progress(at playback: Double) -> Double {
        min(max(playback / playbackDuration, 0), 1)
    }

    /// Highest density recorded for `spot` from the start of playback up to `playback`.
    func peakSpotDensity(for spot: SpotOutcome, upTo playback: Double) -> Double {
        let current = spotDensity(for: spot, at: playback)
        if let analysis = result?.analyses[layoutID],
           let measured = analysis.spots.first(where: { $0.number == spot.number }),
           !measured.densitySamples.isEmpty {
            let step = windowSeconds(at: playback) / Double(max(analysis.sampleIntervalSeconds, 1))
            let low = min(max(Int(step.rounded(.down)), 0), measured.densitySamples.count - 1)
            let pastMax = measured.densitySamples[0...low].max().map(Double.init) ?? 0
            return max(pastMax, current)
        }
        let prog = progress(at: playback)
        if spot.windowDensity.count >= 2 {
            let step = prog * Double(spot.windowDensity.count - 1)
            let low = min(max(Int(step.rounded(.down)), 0), spot.windowDensity.count - 1)
            let pastMax = spot.windowDensity[0...low].max() ?? 0
            return max(pastMax, current)
        }
        return prog >= 0.5 ? max(spot.peakDensity, current) : current
    }

    /// True once a spot has reached Grade E or F at any point up to `playback` (and stays visible afterward).
    func isCongestedSpot(_ spot: SpotOutcome, at playback: Double) -> Bool {
        SeverityGrade.grade(forDensity: peakSpotDensity(for: spot, upTo: playback)).rawValue >= SeverityGrade.e.rawValue
    }

    /// Seconds into the busiest window that `playback` seconds of playback shows.
    func windowSeconds(at playback: Double) -> Double {
        progress(at: playback) * (replay?.durationSeconds ?? 0)
    }

    func clockText(at playback: Double) -> String {
        guard let replay else { return "" }
        return TimeRange.format(replay.startMinute + Int(windowSeconds(at: playback) / 60))
    }

    // MARK: Visitors

    /// Visitors at `playback`, moved between the two nearest frames so they walk smoothly.
    func visitors(at playback: Double) -> [DrawnVisitor] {
        guard let replay, !replay.frames.isEmpty else { return [] }
        let position = windowSeconds(at: playback) / Double(max(replay.frameIntervalSeconds, 1))
        let index = min(Int(position.rounded(.down)), replay.frames.count - 1)
        let current = replay.frames[index]
        let next = replay.frames[min(index + 1, replay.frames.count - 1)]
        let blend = Float(min(max(position - Double(index), 0), 1))
        let nextByID = Dictionary(next.visitors.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })

        return current.visitors.map { visitor in
            let target = nextByID[visitor.id] ?? visitor.position
            let meters = visitor.position + (target - visitor.position) * blend
            let fraction = plan.fraction(of: SIMD2(Double(meters.x), Double(meters.y)))
            return DrawnVisitor(
                id: visitor.id, typeIndex: visitor.typeIndex, point: CGPoint(x: fraction.x, y: fraction.y),
                people: visitor.people, isSeated: visitor.isSeated
            )
        }
    }

    func visitorsInside(at playback: Double) -> Int {
        replay?.frame(at: windowSeconds(at: playback))?.visitors.reduce(0) { $0 + $1.people } ?? 0
    }

    // MARK: Heat and paths

    /// How much of each heat cell is floor, so a corner cell is not read as empty.
    var heatCoverage: [Double] {
        if let cachedCoverage { return cachedCoverage }
        let coverage = replay?.walkable.coverage(columns: Self.heatColumns, rows: heatRows)
            ?? Array(repeating: 1, count: Self.heatColumns * heatRows)
        cachedCoverage = coverage
        return coverage
    }

    /// The floor as one path in plan shares (0 to 1), used to keep the heat off the walls.
    var walkablePath: Path {
        if let cachedWalkablePath { return cachedWalkablePath }
        var path = Path()
        if let mask = replay?.walkable {
            let width = 1 / CGFloat(mask.columns), height = 1 / CGFloat(mask.rows)
            for row in 0..<mask.rows {
                var column = 0
                while column < mask.columns {
                    guard mask.cells[row * mask.columns + column] else { column += 1; continue }
                    let start = column
                    while column < mask.columns, mask.cells[row * mask.columns + column] { column += 1 }
                    path.addRect(CGRect(
                        x: CGFloat(start) * width, y: CGFloat(row) * height,
                        width: CGFloat(column - start) * width, height: height
                    ))
                }
            }
        }
        cachedWalkablePath = path
        return path
    }

    /// People per m² for each heat cell at `playback`, using the Gaussian KDE kernel.
    func heatDensity(at playback: Double) -> [Double] {
        let columns = Self.heatColumns, rows = heatRows
        let sensitivity = CrowdParameters.replayHeatmapSensitivity
        var counts = Array(repeating: 0.0, count: columns * rows)
        for visitor in visitors(at: playback) {
            let column = min(max(Int(visitor.point.x * CGFloat(columns)), 0), columns - 1)
            let row = min(max(Int(visitor.point.y * CGFloat(rows)), 0), rows - 1)
            counts[row * columns + column] += Double(visitor.people) * sensitivity
        }
        let rawCellArea = plan.size.x / Double(columns) * plan.size.y / Double(rows)
        let cellArea = min(max(rawCellArea, 0.85), 1.5)
        let weights = [[0.5, 1.5, 0.5], [1.5, 5.0, 1.5], [0.5, 1.5, 0.5]]
        let coverage = heatCoverage
        var density = Array(repeating: 0.0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                var people = 0.0, area = 0.0
                for dy in -1...1 {
                    for dx in -1...1 {
                        let r = row + dy, c = column + dx
                        guard r >= 0, r < rows, c >= 0, c < columns else { continue }
                        let weight = weights[dy + 1][dx + 1]
                        people += counts[r * columns + c] * weight
                        area += max(coverage[r * columns + c], 0.35) * cellArea * weight
                    }
                }
                density[row * columns + column] = area > 0 ? people / area : 0
            }
        }
        return density
    }

    // MARK: 3D

    /// The venue for the 3D view, built the first time it is needed.
    func venue() -> SimulationVenue? {
        if let cachedVenue { return cachedVenue }
        guard let layout else { return nil }
        let venue = SimulationVenue(
            id: UUID(), blocks: VenueGeometry.blocks(for: layout, legend: legend), plan: plan,
            attractions: VenueGeometry.attractions(in: layout), seats: VenueGeometry.seats(in: layout)
        )
        cachedVenue = venue
        return venue
    }

    /// What the 3D scene shows at `playback`: the visitors, and the overlay for the chosen mode.
    func sceneFrame(at playback: Double) -> SimulationSceneFrame {
        let plan = plan
        func meters(_ share: CGPoint) -> (x: Double, z: Double) {
            (plan.origin.x + Double(share.x) * plan.size.x, plan.origin.y + Double(share.y) * plan.size.y)
        }

        var frame = SimulationSceneFrame()
        frame.visitors = visitors(at: playback).map { visitor in
            let place = meters(visitor.point)
            return SimulationSceneFrame.Visitor(
                id: visitor.id, x: place.x, z: place.z, typeIndex: visitor.typeIndex, people: visitor.people,
                isSeated: visitor.isSeated
            )
        }

        switch mode {
        case .congestion:
            frame.spots = (outcome?.spots ?? []).compactMap { spot in
                guard isCongestedSpot(spot, at: playback) else { return nil }
                let density = spotDensity(for: spot, at: playback)
                let place = meters(spot.location)
                return SimulationSceneFrame.Spot(
                    number: spot.number, x: place.x, z: place.z,
                    level: min(density / SeverityGrade.f.lowerDensity, 1),
                    grade: SeverityGrade.grade(forDensity: density)
                )
            }
        case .density:
            guard let mask = replay?.walkable else { break }
            frame.overlay = FieldImage.pixels(
                kind: .density,
                values: heatDensity(at: playback).map(Float.init),
                columns: Self.heatColumns,
                rows: heatRows,
                mask: mask
            )
        case .footfall:
            guard let replay else { break }
            let smoothed = Self.smoothedFootfall(
                for: footfall(at: playback),
                columns: replay.footfallColumns,
                rows: replay.footfallRows
            )
            let tile = replay.footfallTileM
            frame.overlay = FieldImage.pixels(
                kind: .footfall,
                values: smoothed.map(Float.init),
                columns: replay.footfallColumns,
                rows: replay.footfallRows,
                scale: SIMD2(
                    Float(plan.size.x / (Double(replay.footfallColumns) * tile)),
                    Float(plan.size.y / (Double(replay.footfallRows) * tile))
                ),
                mask: replay.walkable
            )
        }
        return frame
    }

    /// Normalizes cumulative footfall tiles to `0...1` against the 95th percentile of walked tiles so main routes
    /// stand out clearly without being flattened by a single doorway peak.
    static func normalizedFootfall(for counts: [UInt16]) -> [Double] {
        let nonZero = counts.filter { $0 > 0 }.sorted()
        guard !nonZero.isEmpty else { return Array(repeating: 0, count: counts.count) }
        let percentileIndex = Int((Double(nonZero.count - 1) * 0.95).rounded(.down))
        let reference = Double(max(nonZero[percentileIndex], 1))
        return counts.map { count in
            guard count > 0 else { return 0 }
            let ratio = min(Double(count) / reference, 1.0)
            return pow(ratio, 0.75)
        }
    }

    /// Lightly blurs the fine footfall grid along adjacent tiles and normalizes to `0...1` so routes read as
    /// continuous flowing paths instead of isolated grid points.
    static func smoothedFootfall(for counts: [UInt16], columns: Int, rows: Int) -> [Double] {
        guard columns > 0, rows > 0, counts.count == columns * rows else {
            return normalizedFootfall(for: counts)
        }
        var horizontal = Array(repeating: 0.0, count: counts.count)
        for row in 0..<rows {
            let rowOffset = row * columns
            for col in 0..<columns {
                let center = Double(counts[rowOffset + col])
                let left = col > 0 ? Double(counts[rowOffset + col - 1]) : center
                let right = col + 1 < columns ? Double(counts[rowOffset + col + 1]) : center
                horizontal[rowOffset + col] = left * 0.22 + center * 0.56 + right * 0.22
            }
        }
        var smoothed = Array(repeating: 0.0, count: counts.count)
        for row in 0..<rows {
            let rowOffset = row * columns
            let upOffset = max(row - 1, 0) * columns
            let downOffset = min(row + 1, rows - 1) * columns
            for col in 0..<columns {
                smoothed[rowOffset + col] = horizontal[upOffset + col] * 0.22
                    + horizontal[rowOffset + col] * 0.56
                    + horizontal[downOffset + col] * 0.22
            }
        }
        let nonZero = smoothed.filter { $0 > 0.01 }.sorted()
        guard !nonZero.isEmpty else { return Array(repeating: 0, count: counts.count) }
        let percentileIndex = Int((Double(nonZero.count - 1) * 0.95).rounded(.down))
        let reference = max(nonZero[percentileIndex], 0.01)
        return smoothed.map { value in
            guard value > 0.01 else { return 0 }
            let ratio = min(value / reference, 1.0)
            return pow(ratio, 0.78)
        }
    }

    /// Continuous smoothed footfall field for the 2D Walking Routes overlay.
    func walkingRoutesGrid(at playback: Double) -> WalkingRoutesGrid? {
        guard let replay else { return nil }
        let values = Self.smoothedFootfall(
            for: footfall(at: playback),
            columns: replay.footfallColumns,
            rows: replay.footfallRows
        )
        return WalkingRoutesGrid(
            origin: plan.origin,
            tileM: replay.footfallTileM,
            columns: replay.footfallColumns,
            rows: replay.footfallRows,
            values: values
        )
    }

    /// How often each tile of floor has been walked by `playback`.
    func footfall(at playback: Double) -> [UInt16] {
        replay?.frame(at: windowSeconds(at: playback))?.footfall ?? []
    }

    func footfallSummary(at playback: Double) -> (total: Int, busiest: Int) {
        let counts = footfall(at: playback)
        return (counts.reduce(0) { $0 + Int($1) }, Int(counts.max() ?? 0))
    }

    /// Converts interpolated `DrawnVisitor`s into world-metre `SimulatedVisitor`s for `Simulation2DSpriteView`.
    func spriteVisitors(at playback: Double) -> [SimulatedVisitor] {
        let plan = plan
        let states: [VisitorState] = [.walking, .seated, .queueing, .browsing]
        return visitors(at: playback).map { drawn in
            SimulatedVisitor(
                id: drawn.id,
                position: SIMD2(
                    plan.origin.x + Double(drawn.point.x) * plan.size.x,
                    plan.origin.y + Double(drawn.point.y) * plan.size.y
                ),
                state: states[max(0, drawn.typeIndex) % states.count],
                peopleCount: UInt8(clamping: max(1, drawn.people))
            )
        }
    }

    /// Computes 1m x 1m Gaussian KDE density cells for the 2D SpriteKit view with heightened sensitivity
    /// so crowded spots clearly reach orange and red.
    func spriteDensityCells(at playback: Double) -> [DensityCell] {
        guard let layout else { return [] }
        let cols = max(1, Int(ceil(layout.sizeM.x)))
        let rows = max(1, Int(ceil(layout.sizeM.y)))
        var grid = [Double](repeating: 0, count: cols * rows)
        let sensitivity = CrowdParameters.replayHeatmapSensitivity
        let twoSigmaSq = 2.0 * 1.05 * 1.05

        var kernel: [(dx: Int, dy: Int, weight: Double)] = []
        for dy in -2...2 {
            for dx in -2...2 {
                kernel.append((dx, dy, exp(-Double(dx * dx + dy * dy) / twoSigmaSq)))
            }
        }
        let kernelSum = kernel.reduce(0.0) { $0 + $1.weight }

        for visitor in spriteVisitors(at: playback) {
            let col = min(max(Int(floor(visitor.position.x)), 0), cols - 1)
            let row = min(max(Int(floor(visitor.position.y)), 0), rows - 1)
            let people = Double(visitor.peopleCount) * sensitivity
            for item in kernel {
                let nCol = col + item.dx
                let nRow = row + item.dy
                guard nCol >= 0, nRow >= 0, nCol < cols, nRow < rows else { continue }
                grid[nRow * cols + nCol] += people * (item.weight / kernelSum)
            }
        }

        var cells: [DensityCell] = []
        for key in grid.indices where grid[key] >= CrowdParameters.heatmapMinActiveDensity {
            let center = SIMD2(Double(key % cols) + 0.5, Double(key / cols) + 0.5)
            cells.append(DensityCell(id: key, center: center, peoplePerSquareMetre: grid[key]))
        }
        return cells
    }

    /// Converts cumulative footfall tiles or congestion spots into `DensityCell`s for the 2D SpriteKit overlay.
    func spriteOverlayCells(at playback: Double) -> [DensityCell] {
        switch mode {
        case .density:
            return spriteDensityCells(at: playback)
        case .footfall:
            guard let replay else { return [] }
            let normalized = Self.normalizedFootfall(for: footfall(at: playback))
            let tileM = replay.footfallTileM
            let cols = max(replay.footfallColumns, 1)
            let origin = plan.origin
            var cells: [DensityCell] = []
            for index in normalized.indices where normalized[index] > 0 {
                let col = index % cols
                let row = index / cols
                let center = SIMD2(
                    origin.x + (Double(col) + 0.5) * tileM,
                    origin.y + (Double(row) + 0.5) * tileM
                )
                cells.append(DensityCell(id: index, center: center, peoplePerSquareMetre: normalized[index]))
            }
            return cells
        case .congestion:
            guard let spots = outcome?.spots else { return [] }
            let plan = plan
            return spots.compactMap { spot in
                guard isCongestedSpot(spot, at: playback) else { return nil }
                let density = max(0.35, spotDensity(for: spot, at: playback))
                let center = SIMD2(
                    plan.origin.x + Double(spot.location.x) * plan.size.x,
                    plan.origin.y + Double(spot.location.y) * plan.size.y
                )
                return DensityCell(id: spot.number, center: center, peoplePerSquareMetre: density)
            }
        }
    }
}

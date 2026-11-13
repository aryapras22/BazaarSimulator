import Foundation
import Observation
import SwiftUI

/// A visitor placed on the plan: where, as a share of the plan, and who.
struct DrawnVisitor {
    let id: Int
    let typeIndex: Int
    let point: CGPoint
    let people: Int
}

/// Plays back the busiest window of one layout: visitors, crowd density, and the most walked paths.
@Observable
@MainActor
final class SimulationPlayerViewModel {
    /// The window is played back in this many seconds at normal speed.
    static let playbackSeconds = 120.0
    static let heatColumns = 36

    enum Phase: Equatable {
        case loading
        case needsLayouts
        case ready
    }

    let projectID: UUID
    let layoutID: LayoutID
    private let session: any ProjectSessionProtocol
    private let analysisService: any AnalysisServiceProtocol
    private let catalog: PresetCatalog

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
        session: any ProjectSessionProtocol,
        analysisService: any AnalysisServiceProtocol,
        catalog: PresetCatalog
    ) {
        self.projectID = projectID
        self.layoutID = layoutID
        self.session = session
        self.analysisService = analysisService
        self.catalog = catalog
    }

    func load() async {
        switch await SimulationLoader.load(
            projectID: projectID, session: session, analysisService: analysisService, catalog: catalog
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
        guard let window = result?.schedule.window else { return "" }
        return "\(TimeRange.format(window.startMinute)) - \(TimeRange.format(window.endMinute))"
    }

    var heatRows: Int {
        max(Int((Double(Self.heatColumns) * plan.size.y / max(plan.size.x, 1)).rounded()), 1)
    }

    // MARK: Time

    /// How far through the window, 0 to 1, after `playback` seconds of playback.
    func progress(at playback: Double) -> Double {
        min(max(playback / Self.playbackSeconds, 0), 1)
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
            return DrawnVisitor(id: visitor.id, typeIndex: visitor.typeIndex, point: CGPoint(x: fraction.x, y: fraction.y), people: visitor.people)
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

    /// People per m² for each heat cell at `playback`, with its neighbors blended in.
    func heatDensity(at playback: Double) -> [Double] {
        let columns = Self.heatColumns, rows = heatRows
        var counts = Array(repeating: 0.0, count: columns * rows)
        for visitor in visitors(at: playback) {
            let column = min(max(Int(visitor.point.x * CGFloat(columns)), 0), columns - 1)
            let row = min(max(Int(visitor.point.y * CGFloat(rows)), 0), rows - 1)
            counts[row * columns + column] += Double(visitor.people)
        }
        let cellArea = plan.size.x / Double(columns) * plan.size.y / Double(rows)
        let weights = [[1.0, 2, 1], [2, 4, 2], [1, 2, 1]]
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
                        area += max(coverage[r * columns + c], 0.4) * cellArea * weight
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
        let venue = SimulationVenue(id: UUID(), blocks: VenueGeometry.blocks(for: layout), plan: plan)
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
                id: visitor.id, x: place.x, z: place.z, typeIndex: visitor.typeIndex, people: visitor.people
            )
        }

        switch mode {
        case .congestion:
            frame.spots = (outcome?.spots ?? []).map { spot in
                let density = spot.density(at: progress(at: playback))
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
            let counts = footfall(at: playback)
            let busiest = Float(max(counts.max() ?? 1, 1))
            let tile = replay.footfallTileM
            frame.overlay = FieldImage.pixels(
                kind: .footfall,
                values: counts.map { Float($0) / busiest },
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

    /// How often each tile of floor has been walked by `playback`.
    func footfall(at playback: Double) -> [UInt16] {
        replay?.frame(at: windowSeconds(at: playback))?.footfall ?? []
    }

    func footfallSummary(at playback: Double) -> (total: Int, busiest: Int) {
        let counts = footfall(at: playback)
        return (counts.reduce(0) { $0 + Int($1) }, Int(counts.max() ?? 0))
    }
}

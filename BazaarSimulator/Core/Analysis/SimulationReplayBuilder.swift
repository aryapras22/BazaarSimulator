import Foundation
import simd

/// Cuts the busiest window out of a finished run, so the player shows the same visitors the analysis measured.
enum SimulationReplayBuilder {
    static let footfallTileM = 1.0

    @MainActor
    static func build(
        result: SimulationResult,
        layout: Layout,
        windowStartMinute: Int,
        windowMinutes: Int
    ) -> SimulationReplay? {
        guard result.frames.count > 1 else { return nil }
        let interval = max(result.frames[1].elapsedSeconds - result.frames[0].elapsedSeconds, 1)
        let start = Double(windowStartMinute - result.startMinutesFromMidnight) * 60
        let end = start + Double(windowMinutes) * 60
        let frames = result.frames.filter { $0.elapsedSeconds >= start && $0.elapsedSeconds <= end }
        guard !frames.isEmpty else { return nil }

        let columns = max(Int(ceil(layout.sizeM.x / footfallTileM)), 1)
        let rows = max(Int(ceil(layout.sizeM.y / footfallTileM)), 1)
        var footfall = [UInt16](repeating: 0, count: columns * rows)
        var lastTile: [Int: Int] = [:]

        let replayFrames = frames.map { frame -> SimulationReplay.Frame in
            for visitor in frame.visitors {
                let column = min(max(Int(visitor.position.x / footfallTileM), 0), columns - 1)
                let row = min(max(Int(visitor.position.y / footfallTileM), 0), rows - 1)
                let tile = row * columns + column
                guard lastTile[visitor.id] != tile else { continue }
                lastTile[visitor.id] = tile
                footfall[tile] = footfall[tile] &+ UInt16(visitor.peopleCount)
            }
            return SimulationReplay.Frame(
                visitors: frame.visitors.map { visitor in
                    ReplayVisitor(
                        id: visitor.id,
                        position: SIMD2(Float(visitor.position.x), Float(visitor.position.y)),
                        typeIndex: VisitorState.allCases.firstIndex(of: visitor.state) ?? 0,
                        people: Int(visitor.peopleCount)
                    )
                },
                footfall: footfall
            )
        }

        let world = CrowdWorld(layout: layout)
        return SimulationReplay(
            startMinute: windowStartMinute,
            frameIntervalSeconds: Int(interval.rounded()),
            frames: replayFrames,
            walkable: WalkableMask(
                origin: .zero, cellSizeM: CrowdWorld.cellSize,
                columns: world.cols, rows: world.rows, cells: world.walls.floor
            ),
            footfallColumns: columns,
            footfallRows: rows,
            footfallTileM: footfallTileM
        )
    }
}

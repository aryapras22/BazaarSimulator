import Foundation
import simd

/// The part of the layout the plan shows, in layout meters. Spots and visitors are placed by
/// their share of it.
struct PlanFrame: Sendable, Equatable {
    var origin: SIMD2<Double>
    var size: SIMD2<Double>

    static let unit = PlanFrame(origin: .zero, size: SIMD2(1, 1))

    /// A point in meters as a share of the frame, 0 to 1 on each axis.
    func fraction(of point: SIMD2<Double>) -> SIMD2<Double> {
        SIMD2(
            min(max((point.x - origin.x) / max(size.x, 1e-6), 0), 1),
            min(max((point.y - origin.y) / max(size.y, 1e-6), 0), 1)
        )
    }
}

/// Which cells of the plan a visitor can stand on.
struct WalkableMask: Sendable, Equatable {
    let origin: SIMD2<Double>
    let cellSizeM: Double
    let columns: Int
    let rows: Int
    let cells: [Bool]

    /// How much of each cell of a coarser `columns` by `rows` grid is walkable, 0 to 1.
    func coverage(columns targetColumns: Int, rows targetRows: Int) -> [Double] {
        var walkable = Array(repeating: 0.0, count: targetColumns * targetRows)
        var total = Array(repeating: 0.0, count: targetColumns * targetRows)
        for row in 0..<rows {
            let targetRow = min(row * targetRows / max(rows, 1), targetRows - 1)
            for column in 0..<columns {
                let targetColumn = min(column * targetColumns / max(columns, 1), targetColumns - 1)
                let index = targetRow * targetColumns + targetColumn
                total[index] += 1
                if cells[row * columns + column] { walkable[index] += 1 }
            }
        }
        return zip(walkable, total).map { $1 > 0 ? $0 / $1 : 0 }
    }
}

struct ReplayVisitor: Sendable, Equatable {
    /// Stays the same across frames, so playback can move a visitor smoothly between them.
    let id: Int
    /// Layout meters.
    let position: SIMD2<Float>
    /// Index into the visitor types.
    let typeIndex: Int
    /// How many people walk together.
    let people: Int
    /// Sitting on a chair at a table or in a seating block.
    var isSeated = false
}

/// What the simulation looked like through the busiest window: where visitors were, and how often
/// each stretch of floor had been walked.
struct SimulationReplay: Sendable, Equatable {
    struct Frame: Sendable, Equatable {
        let visitors: [ReplayVisitor]
        /// People who have walked into each tile of floor since the window opened.
        let footfall: [UInt16]
    }

    let startMinute: Int
    let frameIntervalSeconds: Int
    let frames: [Frame]
    let walkable: WalkableMask
    let footfallColumns: Int
    let footfallRows: Int
    let footfallTileM: Double

    var durationSeconds: Double {
        Double(max(frames.count - 1, 0) * frameIntervalSeconds)
    }

    /// The frame showing at `seconds` into the window.
    func frame(at seconds: Double) -> Frame? {
        guard !frames.isEmpty else { return nil }
        let index = Int((seconds / Double(max(frameIntervalSeconds, 1))).rounded(.down))
        return frames[min(max(index, 0), frames.count - 1)]
    }
}

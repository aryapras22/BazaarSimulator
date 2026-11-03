import Foundation
import simd

enum BlockedAreaDrawing {
    static let snapCellM = 0.25
    static let minimumDimensionM = 0.5

    /// The placement for a rectangle dragged from `start` to `end` (world metres),
    /// snapped to `snapCellM` unless `snapped` is false. Returns nil when either
    /// side is below `minimumDimensionM`.
    static func placement(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        snapped: Bool = true
    ) -> Placement? {
        func snap(_ value: Double) -> Double {
            snapped ? (value / snapCellM).rounded() * snapCellM : value
        }
        let minX = snap(min(start.x, end.x))
        let maxX = snap(max(start.x, end.x))
        let minY = snap(min(start.y, end.y))
        let maxY = snap(max(start.y, end.y))
        let size = SIMD2<Double>(maxX - minX, maxY - minY)
        guard size.x >= minimumDimensionM, size.y >= minimumDimensionM else { return nil }
        return Placement(
            center: SIMD2<Double>((minX + maxX) / 2, (minY + maxY) / 2),
            sizeM: size
        )
    }

    /// Computes the preview placement during a drag, even if below the minimum dimension.
    static func previewPlacement(
        from start: SIMD2<Double>,
        to end: SIMD2<Double>,
        snapped: Bool = true
    ) -> Placement {
        func snap(_ value: Double) -> Double {
            snapped ? (value / snapCellM).rounded() * snapCellM : value
        }
        let minX = snap(min(start.x, end.x))
        let maxX = snap(max(start.x, end.x))
        let minY = snap(min(start.y, end.y))
        let maxY = snap(max(start.y, end.y))
        let size = SIMD2<Double>(max(0.01, maxX - minX), max(0.01, maxY - minY))
        return Placement(
            center: SIMD2<Double>((minX + maxX) / 2, (minY + maxY) / 2),
            sizeM: size
        )
    }
}

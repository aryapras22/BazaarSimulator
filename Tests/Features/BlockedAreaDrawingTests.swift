import Testing
import simd
@testable import BazaarSimulator

@Suite("Blocked area drawing")
struct BlockedAreaDrawingTests {
    @Test("Snaps dragged rectangle to quarter metres")
    func snapsToQuarterMetres() {
        let placement = BlockedAreaDrawing.placement(
            from: SIMD2<Double>(1.05, 2.15),
            to: SIMD2<Double>(4.85, 6.95),
            snapped: true
        )
        #expect(placement != nil)
        let resolved = placement!
        // 1.05 -> 1.0, 4.85 -> 4.75; width = 3.75; center.x = 2.875
        // 2.15 -> 2.25, 6.95 -> 7.0; height = 4.75; center.y = 4.625
        #expect(abs(resolved.sizeM.x - 3.75) < 0.001)
        #expect(abs(resolved.sizeM.y - 4.75) < 0.001)
        #expect(abs(resolved.center.x - 2.875) < 0.001)
        #expect(abs(resolved.center.y - 4.625) < 0.001)
    }

    @Test("Normalises backwards drag so size is positive")
    func normalisesBackwardsDrag() {
        let placement = BlockedAreaDrawing.placement(
            from: SIMD2<Double>(5.0, 5.0),
            to: SIMD2<Double>(1.0, 2.0),
            snapped: true
        )
        #expect(placement != nil)
        let resolved = placement!
        #expect(resolved.sizeM.x == 4.0)
        #expect(resolved.sizeM.y == 3.0)
        #expect(resolved.center.x == 3.0)
        #expect(resolved.center.y == 3.5)
    }

    @Test("Rejects rectangle below minimum dimension")
    func rejectsBelowMinimumDimension() {
        let tooNarrow = BlockedAreaDrawing.placement(
            from: SIMD2<Double>(1.0, 1.0),
            to: SIMD2<Double>(1.25, 3.0),
            snapped: true
        )
        #expect(tooNarrow == nil)

        let tooShort = BlockedAreaDrawing.placement(
            from: SIMD2<Double>(1.0, 1.0),
            to: SIMD2<Double>(3.0, 1.25),
            snapped: true
        )
        #expect(tooShort == nil)
    }

    @Test("Preserves exact coordinates when unsnapped")
    func preservesExactWhenUnsnapped() {
        let placement = BlockedAreaDrawing.placement(
            from: SIMD2<Double>(1.123, 2.456),
            to: SIMD2<Double>(4.789, 7.891),
            snapped: false
        )
        #expect(placement != nil)
        let resolved = placement!
        #expect(abs(resolved.sizeM.x - (4.789 - 1.123)) < 0.001)
        #expect(abs(resolved.sizeM.y - (7.891 - 2.456)) < 0.001)
    }

    @Test("Preview placement produces valid size even when small")
    func previewPlacementProducesNonZeroSize() {
        let preview = BlockedAreaDrawing.previewPlacement(
            from: SIMD2<Double>(1.0, 1.0),
            to: SIMD2<Double>(1.0, 1.0),
            snapped: false
        )
        #expect(preview.sizeM.x > 0)
        #expect(preview.sizeM.y > 0)
    }
}

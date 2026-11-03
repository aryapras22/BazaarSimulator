import Testing
import simd
@testable import BazaarSimulator

@Suite("Placement resizing")
struct PlacementResizingTests {
    @Test("Trailing handle drag increases width, keeps length, pins leading edge")
    func trailingHandleIncreasesWidth() {
        let initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        let resized = PlacementResizing.resized(
            placement: initial,
            handle: .trailing,
            deltaWorld: SIMD2<Double>(1.0, 0.5),
            snapped: true
        )
        // Width becomes 5.0, length stays 4.0
        #expect(abs(resized.sizeM.x - 5.0) < 0.001)
        #expect(abs(resized.sizeM.y - 4.0) < 0.001)
        // Leading edge in world was 10 - 2 = 8. Now 10.5 - 2.5 = 8 (pinned)
        #expect(abs((resized.center.x - resized.sizeM.x / 2) - 8.0) < 0.001)
        #expect(abs(resized.center.y - 10.0) < 0.001)
    }

    @Test("Top handle drag changes length and pins bottom edge")
    func topHandlePinsBottomEdge() {
        let initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        // Dragging top upwards (-Y in screen/canvas space) increases length
        let resized = PlacementResizing.resized(
            placement: initial,
            handle: .top,
            deltaWorld: SIMD2<Double>(0, -1.0),
            snapped: true
        )
        #expect(abs(resized.sizeM.x - 4.0) < 0.001)
        #expect(abs(resized.sizeM.y - 5.0) < 0.001)
        // Bottom edge in world was 10 + 2 = 12. Now 9.5 + 2.5 = 12 (pinned)
        #expect(abs((resized.center.y + resized.sizeM.y / 2) - 12.0) < 0.001)
        #expect(abs(resized.center.x - 10.0) < 0.001)
    }

    @Test("Corner handle changes both dimensions")
    func cornerHandleChangesBothDimensions() {
        let initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        let resized = PlacementResizing.resized(
            placement: initial,
            handle: .bottomTrailing,
            deltaWorld: SIMD2<Double>(1.0, 2.0),
            snapped: true
        )
        #expect(abs(resized.sizeM.x - 5.0) < 0.001)
        #expect(abs(resized.sizeM.y - 6.0) < 0.001)
        // Pinned top-leading corner was (8, 8)
        #expect(abs((resized.center.x - resized.sizeM.x / 2) - 8.0) < 0.001)
        #expect(abs((resized.center.y - resized.sizeM.y / 2) - 8.0) < 0.001)
    }

    @Test("Rotated area resizes along local axes")
    func rotatedAreaResizesAlongLocalAxes() {
        var initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 2),
            rotationRadians: 0
        )
        initial.rotationDegrees = 90
        // At 90 deg rotation, local +X (trailing) points along world +Y
        let resized = PlacementResizing.resized(
            placement: initial,
            handle: .trailing,
            deltaWorld: SIMD2<Double>(0, 1.0),
            snapped: true
        )
        #expect(abs(resized.sizeM.x - 5.0) < 0.001)
        #expect(abs(resized.sizeM.y - 2.0) < 0.001)
        #expect(resized.rotationDegrees == 90)
    }

    @Test("Clamps to minimum dimension in all directions")
    func clampsToMinimumDimension() {
        let initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        // Drag trailing way to the left
        let shrunkW = PlacementResizing.resized(
            placement: initial,
            handle: .trailing,
            deltaWorld: SIMD2<Double>(-10.0, 0),
            snapped: true
        )
        #expect(shrunkW.sizeM.x == PlacementResizing.minimumDimensionM)
        // Leading edge was 8. Now 8 + 0.5 = 8.5 trailing edge. Pinned at 8.
        #expect(abs((shrunkW.center.x - shrunkW.sizeM.x / 2) - 8.0) < 0.001)

        // Drag top way downwards
        let shrunkH = PlacementResizing.resized(
            placement: initial,
            handle: .top,
            deltaWorld: SIMD2<Double>(0, 10.0),
            snapped: true
        )
        #expect(shrunkH.sizeM.y == PlacementResizing.minimumDimensionM)
        // Bottom edge was 12. Pinned at 12.
        #expect(abs((shrunkH.center.y + shrunkH.sizeM.y / 2) - 12.0) < 0.001)
    }

    @Test("Unsnapped drag preserves fractional metres")
    func unsnappedDragPreservesFractionalMetres() {
        let initial = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        let resized = PlacementResizing.resized(
            placement: initial,
            handle: .trailing,
            deltaWorld: SIMD2<Double>(0.333, 0),
            snapped: false
        )
        #expect(abs(resized.sizeM.x - 4.333) < 0.001)
    }

    @Test("Hit test detects handle within hit radius")
    func hitTestDetectsHandle() {
        let placement = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        // Trailing handle is at (12, 10)
        let hit = PlacementResizing.hitTest(
            placement: placement,
            pointerWorld: SIMD2<Double>(12.05, 10.0),
            pointsPerMetre: 20
        )
        #expect(hit == .trailing)

        let miss = PlacementResizing.hitTest(
            placement: placement,
            pointerWorld: SIMD2<Double>(10.0, 10.0),
            pointsPerMetre: 20
        )
        #expect(miss == nil)
    }
}

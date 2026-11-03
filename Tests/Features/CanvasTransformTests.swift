import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct CanvasTransformTests {
    @Test("toWorld after toView returns the original world point")
    func roundTrip() {
        let transform = CanvasTransform(scale: 15.0, offset: SIMD2<Double>(40, 60))
        let point = SIMD2<Double>(12.5, 34.2)

        let roundTripped = transform.toWorld(transform.toView(point))

        #expect(simd_distance(roundTripped, point) < 1e-9)
    }

    @Test("Zoom keeps the world point under the pointer fixed")
    func zoomKeepsAnchorFixed() {
        let initial = CanvasTransform(scale: 10.0, offset: SIMD2<Double>(50, 30))
        let anchorView = SIMD2<Double>(300, 250)
        let worldBefore = initial.toWorld(anchorView)

        let zoomed = initial.zoomed(by: 1.5, around: anchorView)
        let worldAfter = zoomed.toWorld(anchorView)

        #expect(simd_distance(worldBefore, worldAfter) < 1e-9)
    }

    @Test("Fit centers a 70 x 84 m layout in a 1000 x 800 view with padding")
    func fitCentersLayout() {
        let layoutSize = SIMD2<Double>(70, 84)
        let viewSize = SIMD2<Double>(1000, 800)

        let fitted = CanvasTransform.fitting(layoutSize: layoutSize, in: viewSize, padding: 40)

        let expectedScale = (800.0 - 80.0) / 84.0
        #expect(abs(fitted.scale - expectedScale) < 1e-6)
        let centerInView = fitted.toView(layoutSize / 2.0)
        #expect(simd_distance(centerInView, viewSize / 2.0) < 1e-6)
    }

    @Test("Scale clamps to 4 and 80")
    func scaleClamps() {
        let base = CanvasTransform(scale: 10.0)
        let anchor = SIMD2<Double>(100, 100)

        let zoomedOut = base.zoomed(by: 0.01, around: anchor)
        let zoomedIn = base.zoomed(by: 100.0, around: anchor)

        #expect(zoomedOut.scale == CanvasTransform.minScale)
        #expect(zoomedIn.scale == CanvasTransform.maxScale)
    }

    @Test("Scroll zoom keeps the point under the pointer fixed")
    func scrollZoomKeepsAnchorFixed() {
        let initial = CanvasTransform(scale: 12.0, offset: SIMD2<Double>(40, 20))
        let anchorView = SIMD2<Double>(240, 180)
        let worldBefore = initial.toWorld(anchorView)

        let zoomedPrecise = initial.zoomedForScroll(deltaY: 120.0, isPrecise: true, around: anchorView)
        let zoomedLine = initial.zoomedForScroll(deltaY: 2.0, isPrecise: false, around: anchorView)

        #expect(zoomedPrecise.scale > initial.scale)
        #expect(simd_distance(worldBefore, zoomedPrecise.toWorld(anchorView)) < 1e-9)
        #expect(zoomedLine.scale > initial.scale)
        #expect(simd_distance(worldBefore, zoomedLine.toWorld(anchorView)) < 1e-9)
    }

    @Test("One mouse-wheel line zooms by about 10 percent")
    func oneMouseWheelLineZoomsByTenPercent() {
        let start = CanvasTransform(scale: 10.0)
        let result = start.zoomedForScroll(deltaY: 1, isPrecise: false, around: .zero)

        #expect(abs(result.scale / start.scale - 1.1) < 1e-9)
    }

    @Test("A fast wheel spin is clamped")
    func fastWheelSpinIsClamped() {
        let start = CanvasTransform(scale: 10.0)
        let spunFast = start.zoomedForScroll(deltaY: 50, isPrecise: false, around: .zero)
        let clampedAtTen = start.zoomedForScroll(deltaY: 10, isPrecise: false, around: .zero)

        #expect(abs(spunFast.scale - clampedAtTen.scale) < 1e-9)
    }
}

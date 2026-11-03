import Foundation
import simd

struct CanvasTransform: Hashable, Sendable {
    static let minScale: Double = 4.0
    static let maxScale: Double = 80.0
    static let preciseScrollZoomBase = 1.0015
    static let lineScrollZoomBase = 1.1

    var scale: Double
    var offset: SIMD2<Double>

    init(scale: Double = 10.0, offset: SIMD2<Double> = .zero) {
        self.scale = min(max(scale, Self.minScale), Self.maxScale)
        self.offset = offset
    }

    func toView(_ world: SIMD2<Double>) -> SIMD2<Double> {
        world * scale + offset
    }

    func toWorld(_ view: SIMD2<Double>) -> SIMD2<Double> {
        (view - offset) / scale
    }

    static func fitting(
        layoutSize: SIMD2<Double>,
        in viewSize: SIMD2<Double>,
        padding: Double = 56.0
    ) -> CanvasTransform {
        guard layoutSize.x > 0, layoutSize.y > 0, viewSize.x > 0, viewSize.y > 0 else {
            return CanvasTransform()
        }
        let availableW = max(1.0, viewSize.x - padding * 2.0)
        let availableH = max(1.0, viewSize.y - padding * 2.0)
        let rawScale = min(availableW / layoutSize.x, availableH / layoutSize.y)
        let clampedScale = min(max(rawScale, minScale), maxScale)
        let drawnSize = layoutSize * clampedScale
        let centeredOffset = (viewSize - drawnSize) / 2.0
        return CanvasTransform(scale: clampedScale, offset: centeredOffset)
    }

    func zoomed(by factor: Double, around anchorView: SIMD2<Double>) -> CanvasTransform {
        let worldAtAnchor = toWorld(anchorView)
        let newScale = min(max(scale * factor, Self.minScale), Self.maxScale)
        let newOffset = anchorView - worldAtAnchor * newScale
        return CanvasTransform(scale: newScale, offset: newOffset)
    }

    func zoomedForScroll(deltaY: Double, isPrecise: Bool, around anchorView: SIMD2<Double>) -> CanvasTransform {
        let base = isPrecise ? Self.preciseScrollZoomBase : Self.lineScrollZoomBase
        let clampedDelta = isPrecise ? deltaY : min(max(deltaY, -10), 10)
        return zoomed(by: pow(base, clampedDelta), around: anchorView)
    }

    func panned(by delta: SIMD2<Double>) -> CanvasTransform {
        CanvasTransform(scale: scale, offset: offset + delta)
    }
}

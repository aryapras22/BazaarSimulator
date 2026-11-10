import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct BoothShapeTests {
    @Test("Booth shape with [.right, .bottom] gives two panels and two counters on the right sides")
    func rightBottomOpenSides() {
        let size = SIMD2<Double>(2.5, 2.5)
        let openSides: OpenSides = [.right, .bottom]
        let primitives = BoothShape.primitives(size: size, openSides: openSides)

        let panels = primitives.filter { $0.role == .panel }
        let counters = primitives.filter { $0.role == .counter }
        let fascias = primitives.filter { $0.role == .fascia }

        #expect(panels.count == 2)
        #expect(counters.count == 2)
        #expect(fascias.count == 2)

        // Closed sides (.top, .left) have panels
        for panel in panels {
            guard case let .box(center, size, _, _) = panel else {
                Issue.record("Panel must be a box")
                continue
            }
            #expect(size.y == BoothShape.panelHeightM)
            let isTop = center.z < 0 && abs(center.x) < 0.001
            let isLeft = center.x < 0 && abs(center.z) < 0.001
            #expect(isTop || isLeft, "Panel should be at top or left")
        }

        // Open sides (.bottom, .right) have counters and fascias
        for counter in counters {
            guard case let .box(center, size, _, _) = counter else {
                Issue.record("Counter must be a box")
                continue
            }
            #expect(size.y == BoothShape.counterHeightM)
            let isBottom = center.z > 0 && abs(center.x) < 0.001
            let isRight = center.x > 0 && abs(center.z) < 0.001
            #expect(isBottom || isRight, "Counter should be at bottom or right")
        }

        for fascia in fascias {
            guard case let .box(center, size, _, _) = fascia else {
                Issue.record("Fascia must be a box")
                continue
            }
            #expect(size.y == BoothShape.fasciaDepthM)
            let topY = center.y + size.y / 2.0
            #expect(abs(topY - BoothShape.panelHeightM) < 0.001)
            let isBottom = center.z > 0 && abs(center.x) < 0.001
            let isRight = center.x > 0 && abs(center.z) < 0.001
            #expect(isBottom || isRight, "Fascia should be at bottom or right")
        }
    }

    @Test("Booth with no open sides produces four panels")
    func allClosedSides() {
        let size = SIMD2<Double>(2.0, 3.0)
        let primitives = BoothShape.primitives(size: size, openSides: [])
        let panels = primitives.filter { $0.role == .panel }

        #expect(primitives.count == 4)
        #expect(panels.count == 4)
    }

    @Test("Booth with all open sides produces four counters and four fascias")
    func allOpenSides() {
        let size = SIMD2<Double>(2.0, 2.0)
        let primitives = BoothShape.primitives(size: size, openSides: .all)
        let counters = primitives.filter { $0.role == .counter }
        let fascias = primitives.filter { $0.role == .fascia }

        #expect(primitives.count == 8)
        #expect(counters.count == 4)
        #expect(fascias.count == 4)
    }

    @Test("Booth primitives stay inside the footprint bounds")
    func boothPrimitivesStayInsideBounds() {
        let tolerance = 0.001
        let testCases: [(SIMD2<Double>, OpenSides)] = [
            (SIMD2(2.0, 2.0), []),
            (SIMD2(2.5, 2.5), [.right, .bottom]),
            (SIMD2(3.0, 4.0), [.top]),
            (SIMD2(5.0, 5.0), .all)
        ]

        for (size, sides) in testCases {
            let primitives = BoothShape.primitives(size: size, openSides: sides)
            let halfW = size.x / 2.0
            let halfD = size.y / 2.0

            for primitive in primitives {
                let bounds = primitive.bounds
                #expect(bounds.min.x >= -halfW - tolerance)
                #expect(bounds.max.x <= halfW + tolerance)
                #expect(bounds.min.z >= -halfD - tolerance)
                #expect(bounds.max.z <= halfD + tolerance)
                #expect(bounds.min.y >= -tolerance)
                #expect(bounds.max.y <= BoothShape.panelHeightM + tolerance)
            }
        }
    }
}

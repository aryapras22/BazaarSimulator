import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct SelectGestureTests {
    @Test("Threshold distinguishes below, at, and above 4 pt")
    func dragThreshold() {
        #expect(!SelectGesture.isPastThreshold(SIMD2<Double>(0, 0)))
        #expect(!SelectGesture.isPastThreshold(SIMD2<Double>(3.99, 0)))
        #expect(!SelectGesture.isPastThreshold(SIMD2<Double>(0, 4.0)))
        #expect(!SelectGesture.isPastThreshold(SIMD2<Double>(-4.0, 0)))
        #expect(SelectGesture.isPastThreshold(SIMD2<Double>(4.01, 0)))
        #expect(SelectGesture.isPastThreshold(SIMD2<Double>(3.0, 3.0)))

        #expect(!SelectGesture.isPastThreshold(CGPoint(x: 2.0, y: 2.0)))
        #expect(!SelectGesture.isPastThreshold(CGPoint(x: 4.0, y: 0)))
        #expect(SelectGesture.isPastThreshold(CGPoint(x: 4.1, y: 0)))
        #expect(SelectGesture.isPastThreshold(CGPoint(x: 0, y: -4.1)))
    }

    @Test("Axis lock preserves the primary axis and zeros the secondary")
    func axisLock() {
        let horizontal = SelectGesture.lockAxis(SIMD2<Double>(10.0, 3.0))
        #expect(horizontal == SIMD2<Double>(10.0, 0))

        let vertical = SelectGesture.lockAxis(SIMD2<Double>(2.0, 8.0))
        #expect(vertical == SIMD2<Double>(0, 8.0))

        let negHorizontal = SelectGesture.lockAxis(SIMD2<Double>(-7.0, 2.0))
        #expect(negHorizontal == SIMD2<Double>(-7.0, 0))

        let negVertical = SelectGesture.lockAxis(SIMD2<Double>(3.0, -9.0))
        #expect(negVertical == SIMD2<Double>(0, -9.0))

        let bothNegative = SelectGesture.lockAxis(SIMD2<Double>(-1.0, -5.0))
        #expect(bothNegative == SIMD2<Double>(0, -5.0))

        let equalComponents = SelectGesture.lockAxis(SIMD2<Double>(5.0, 5.0))
        #expect(equalComponents == SIMD2<Double>(5.0, 0))

        let equalNegative = SelectGesture.lockAxis(SIMD2<Double>(-4.0, 4.0))
        #expect(equalNegative == SIMD2<Double>(-4.0, 0))
    }

    @Test("Marquee touched booths matches fully inside, intersecting, outside, and ignores non-booths")
    func marqueeTouchedBooths() {
        let boothInside = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let boothIntersecting = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(15, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let boothOutside = LayoutObject(
            kind: .booth,
            label: "B3",
            placement: Placement(center: SIMD2<Double>(25, 25), sizeM: SIMD2<Double>(2, 2))
        )
        let blockInside = LayoutObject(
            kind: .block,
            label: "K1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(1, 1))
        )
        let wallInside = LayoutObject(
            kind: .wall,
            label: "W1",
            placement: Placement(center: SIMD2<Double>(9, 9), sizeM: SIMD2<Double>(2, 0.2))
        )

        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(30, 30),
            objects: [boothInside, boothIntersecting, boothOutside, blockInside, wallInside]
        )

        let marqueeStart = SIMD2<Double>(8, 8)
        let marqueeEnd = SIMD2<Double>(14.5, 12)

        let touched = SelectGesture.touchedBooths(from: marqueeStart, to: marqueeEnd, layout: layout)

        #expect(touched.contains(boothInside.id))
        #expect(touched.contains(boothIntersecting.id))
        #expect(!touched.contains(boothOutside.id))
        #expect(!touched.contains(blockInside.id))
        #expect(!touched.contains(wallInside.id))
        #expect(touched.count == 2)
    }
}

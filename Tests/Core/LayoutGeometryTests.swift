import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutGeometryTests {
    @Test("Corners of a 90 degree rotated 2 x 4 rect match the swapped dimensions")
    func rotatedCorners() {
        let placement = Placement(
            center: SIMD2<Double>(10, 20),
            sizeM: SIMD2<Double>(2, 4),
            rotationRadians: .pi / 2
        )

        let bounds = LayoutGeometry.bounds(of: placement)

        #expect(abs(bounds.minX - 8.0) < 1e-6)
        #expect(abs(bounds.maxX - 12.0) < 1e-6)
        #expect(abs(bounds.minY - 19.0) < 1e-6)
        #expect(abs(bounds.maxY - 21.0) < 1e-6)
    }

    @Test("Intersection is true for overlapping rotated rects and false for touching edges")
    func intersectionBehavior() {
        let first = Placement(
            center: SIMD2<Double>(5, 5),
            sizeM: SIMD2<Double>(2, 4),
            rotationRadians: .pi / 4
        )
        let overlapping = Placement(
            center: SIMD2<Double>(6, 5),
            sizeM: SIMD2<Double>(2, 2),
            rotationRadians: 0
        )
        let touching = Placement(
            center: SIMD2<Double>(2, 2),
            sizeM: SIMD2<Double>(2, 2),
            rotationRadians: 0
        )
        let adjacent = Placement(
            center: SIMD2<Double>(4, 2),
            sizeM: SIMD2<Double>(2, 2),
            rotationRadians: 0
        )

        #expect(LayoutGeometry.intersects(first, overlapping))
        #expect(!LayoutGeometry.intersects(touching, adjacent))
    }

    @Test("Polygon contains a point inside the chamfered lobby and excludes the cut corner")
    func polygonContainsChamferedLobby() {
        let lobby: [SIMD2<Double>] = [
            SIMD2<Double>(38.75, 65.15),
            SIMD2<Double>(62.78, 65.15),
            SIMD2<Double>(62.78, 83.13),
            SIMD2<Double>(40.53, 83.13),
            SIMD2<Double>(38.75, 81.16)
        ]

        let insidePoint = SIMD2<Double>(50.0, 74.0)
        let cutCornerPoint = SIMD2<Double>(39.0, 82.9)

        #expect(LayoutGeometry.polygonContains(lobby, point: insidePoint))
        #expect(!LayoutGeometry.polygonContains(lobby, point: cutCornerPoint))
    }
}

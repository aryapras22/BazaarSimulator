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

    @Test("Overlap depth is positive for overlapping rects and zero or negative for touching ones")
    func overlapDepthBehavior() {
        let first = Placement(center: SIMD2<Double>(2, 2), sizeM: SIMD2<Double>(2, 2))
        let overlapping = Placement(center: SIMD2<Double>(3.5, 2), sizeM: SIMD2<Double>(2, 2))
        let touching = Placement(center: SIMD2<Double>(4, 2), sizeM: SIMD2<Double>(2, 2))
        let separated = Placement(center: SIMD2<Double>(5, 2), sizeM: SIMD2<Double>(2, 2))

        #expect(LayoutGeometry.overlapDepth(first, overlapping) > 0)
        #expect(LayoutGeometry.overlapDepth(first, touching) <= 0)
        #expect(LayoutGeometry.overlapDepth(first, separated) < 0)
    }

    @Test("A 0.05 m overlap is below the validator tolerance")
    func minorOverlapBelowTolerance() {
        let hall: [SIMD2<Double>] = [
            SIMD2<Double>(0, 0), SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20), SIMD2<Double>(0, 20)
        ]
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: .top
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(6.95, 5), sizeM: SIMD2<Double>(2, 2)),
            openSides: .top
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: hall,
            objects: [boothA, boothB]
        )

        #expect(LayoutValidator.issues(in: layout).filter { $0.kind == .overlappingObjects }.isEmpty)
    }

    @Test("Placement inside floor object is considered inside walkable floor")
    func placementInsideFloorObject() {
        let floor = LayoutObject(
            kind: .floor,
            label: "Floor 1",
            placement: Placement(center: SIMD2(30, 30), sizeM: SIMD2(10, 10))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2(50, 50), objects: [floor])
        let boothInside = Placement(center: SIMD2(30, 30), sizeM: SIMD2(2, 2))
        let boothOutside = Placement(center: SIMD2(40, 40), sizeM: SIMD2(2, 2))

        #expect(LayoutGeometry.isPlacementInsideWalkableFloor(boothInside, in: layout))
        #expect(!LayoutGeometry.isPlacementInsideWalkableFloor(boothOutside, in: layout))
    }
}

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

    @Test("A round footprint holds points on its oval but not the corners of its box")
    func roundFootprintContainment() {
        let oval = Placement(center: .zero, sizeM: SIMD2<Double>(4, 2), shape: .round)
        let box = Placement(center: .zero, sizeM: SIMD2<Double>(4, 2))

        #expect(LayoutGeometry.contains(oval, point: SIMD2<Double>(1.9, 0)))
        #expect(LayoutGeometry.contains(oval, point: SIMD2<Double>(0, 0.95)))
        #expect(!LayoutGeometry.contains(oval, point: SIMD2<Double>(1.8, 0.8)))
        #expect(LayoutGeometry.contains(box, point: SIMD2<Double>(1.8, 0.8)))
    }

    @Test("A round column misses a box corner its bounding box hits, and two columns overlap by their shared depth")
    func roundFootprintOverlap() {
        let box = Placement(center: SIMD2<Double>(1, 1), sizeM: SIMD2<Double>(2, 2))
        let nearCorner = Placement(center: SIMD2<Double>(2.8, 2.8), sizeM: SIMD2<Double>(2, 2), shape: .round)
        let column = Placement(center: .zero, sizeM: SIMD2<Double>(2, 2), shape: .round)
        let neighbour = Placement(center: SIMD2<Double>(1.5, 0), sizeM: SIMD2<Double>(2, 2), shape: .round)

        #expect(!LayoutGeometry.intersects(box, nearCorner))
        #expect(abs(LayoutGeometry.overlapDepth(column, neighbour) - 0.5) < 0.05)
    }

    @Test("A placement saved before shapes existed reads as a rectangle")
    func placementWithoutShapeDecodesAsRect() throws {
        let json = Data(#"{"center":[1,2],"sizeM":[3,4],"rotationRadians":0}"#.utf8)

        let placement = try JSONDecoder().decode(Placement.self, from: json)

        #expect(placement.shape == .rect)
    }
}

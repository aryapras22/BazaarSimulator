import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct HallFloorPolygonTests {
    @Test("PolygonTriangulator handles convex polygons in both winding orders")
    func triangulatesConvexPolygon() {
        for polygon in [FloorFixtures.convexCCW, FloorFixtures.convexCW] {
            let triangles = PolygonTriangulator.triangulate(polygon)

            #expect(triangles.count == polygon.count - 2)
            FloorChecks.verifyTriangulation(triangles, of: polygon)
        }
    }

    @Test("PolygonTriangulator triangulates a concave notched hall without crossing the notch")
    func triangulatesNotchedHall() {
        for polygon in [FloorFixtures.notchedCCW, FloorFixtures.notchedCW] {
            let triangles = PolygonTriangulator.triangulate(polygon)

            #expect(triangles.count == polygon.count - 2)
            FloorChecks.verifyTriangulation(triangles, of: polygon, excludedPoints: [FloorFixtures.topNotchCenter])
        }
    }

    @Test("PolygonTriangulator triangulates a double-notched concave hall in both winding orders")
    func triangulatesDoubleNotchedHall() {
        let excluded = [FloorFixtures.topNotchCenter, FloorFixtures.bottomNotchCenter]

        for polygon in [FloorFixtures.doubleNotchedCCW, FloorFixtures.doubleNotchedCW] {
            let triangles = PolygonTriangulator.triangulate(polygon)

            #expect(triangles.count == polygon.count - 2)
            FloorChecks.verifyTriangulation(triangles, of: polygon, excludedPoints: excluded)
        }
    }

    @Test("PolygonTriangulator handles concave polygons with collinear edge vertices")
    func triangulatesCollinearVertices() {
        for polygon in [FloorFixtures.collinearNotchedCCW, FloorFixtures.collinearNotchedCW] {
            let triangles = PolygonTriangulator.triangulate(polygon)

            FloorChecks.verifyTriangulation(triangles, of: polygon, excludedPoints: [FloorFixtures.topNotchCenter])
        }
    }

    @Test("PolygonTriangulator returns empty for fewer than three vertices")
    func returnsEmptyForDegeneratePolygons() {
        #expect(PolygonTriangulator.triangulate([]).isEmpty)
        #expect(PolygonTriangulator.triangulate([SIMD2(0, 0)]).isEmpty)
        #expect(PolygonTriangulator.triangulate([SIMD2(0, 0), SIMD2(4, 0)]).isEmpty)
    }

    @Test("TriangleMesh floor polygon keeps upward normals and area for convex halls")
    func triangleMeshConvexFloorFacesUp() {
        for polygon in [FloorFixtures.convexCCW, FloorFixtures.convexCW] {
            var mesh = TriangleMesh()
            mesh.appendFloorPolygon(polygon, heightY: 0.25)

            #expect(mesh.triangleCount == polygon.count - 2)
            FloorChecks.verifyTriangleMesh(mesh, for: polygon, heightY: 0.25)
        }
    }

    @Test("TriangleMesh floor polygon stays inside concave notched halls in both winding orders")
    func triangleMeshNotchedFloorExcludesNotch() {
        for polygon in [FloorFixtures.notchedCCW, FloorFixtures.notchedCW] {
            var mesh = TriangleMesh()
            mesh.appendFloorPolygon(polygon, heightY: 0.0)

            #expect(mesh.triangleCount == polygon.count - 2)
            FloorChecks.verifyTriangleMesh(
                mesh, for: polygon, heightY: 0.0, excludedPoints: [FloorFixtures.topNotchCenter]
            )
        }
    }

    @Test("TriangleMesh floor polygon handles double-notched and collinear concave halls")
    func triangleMeshDoubleNotchedAndCollinearFloor() {
        var doubleNotchMesh = TriangleMesh()
        doubleNotchMesh.appendFloorPolygon(FloorFixtures.doubleNotchedCW, heightY: 0.1)

        FloorChecks.verifyTriangleMesh(
            doubleNotchMesh,
            for: FloorFixtures.doubleNotchedCW,
            heightY: 0.1,
            excludedPoints: [FloorFixtures.topNotchCenter, FloorFixtures.bottomNotchCenter]
        )

        var collinearMesh = TriangleMesh()
        collinearMesh.appendFloorPolygon(FloorFixtures.collinearNotchedCCW, heightY: 0.0)

        FloorChecks.verifyTriangleMesh(
            collinearMesh,
            for: FloorFixtures.collinearNotchedCCW,
            heightY: 0.0,
            excludedPoints: [FloorFixtures.topNotchCenter]
        )
    }

    @Test("SceneGeometryBuilder builds concave hall floor geometry without filling the notch")
    func sceneGeometryBuilderUsesConcaveFloor() throws {
        let layout = Layout(name: "Notched Hall", sizeM: SIMD2(20, 12), hall: FloorFixtures.notchedCCW)

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: Legend())
        let floorMesh = try #require(geometry.meshes[SceneMaterialKey(role: .floor, tint: nil)])

        FloorChecks.verifyTriangleMesh(
            floorMesh, for: FloorFixtures.notchedCCW, heightY: 0.0, excludedPoints: [FloorFixtures.topNotchCenter]
        )
    }

    @Test("MeshData.floorSlab builds top, bottom, and outward rim for convex halls")
    func floorSlabConvexHasTopBottomAndRim() {
        for polygon in [FloorFixtures.convexCCW, FloorFixtures.convexCW] {
            let points = polygon.map { SIMD2<Float>(Float($0.x), Float($0.y)) }

            let slab = MeshData.floorSlab(polygon: points, topY: 0.2, thickness: 0.1)

            FloorChecks.verifyFloorSlab(slab, for: polygon, topY: 0.2, thickness: 0.1)
        }
    }

    @Test("MeshData.floorSlab excludes the notch for concave halls in both winding orders")
    func floorSlabNotchedHallExcludesNotch() {
        for polygon in [FloorFixtures.notchedCCW, FloorFixtures.notchedCW] {
            let points = polygon.map { SIMD2<Float>(Float($0.x), Float($0.y)) }

            let slab = MeshData.floorSlab(polygon: points, topY: 0, thickness: 0.1)

            FloorChecks.verifyFloorSlab(
                slab, for: polygon, topY: 0, thickness: 0.1, excludedPoints: [FloorFixtures.topNotchCenter]
            )
        }
    }

    @Test("MeshData.floorSlab handles collinear concave polygons and returns empty when degenerate")
    func floorSlabCollinearAndDegenerate() {
        let collinearPoints = FloorFixtures.collinearNotchedCCW.map { SIMD2<Float>(Float($0.x), Float($0.y)) }

        let slab = MeshData.floorSlab(polygon: collinearPoints, topY: 0, thickness: 0.1)
        let emptySlab = MeshData.floorSlab(polygon: [SIMD2(0, 0), SIMD2(5, 0)], topY: 0, thickness: 0.1)

        FloorChecks.verifyFloorSlab(
            slab, for: FloorFixtures.collinearNotchedCCW, topY: 0, thickness: 0.1,
            excludedPoints: [FloorFixtures.topNotchCenter]
        )
        #expect(emptySlab.vertices.isEmpty)
        #expect(emptySlab.indices.isEmpty)
    }

    @Test("VenueGeometry emits polygon floor blocks for notched and convex halls")
    func venueGeometryEmitsPolygonForHall() throws {
        let cases: [([SIMD2<Double>], [SIMD2<Double>])] = [
            (FloorFixtures.notchedCCW, [FloorFixtures.topNotchCenter]),
            (FloorFixtures.notchedCW, [FloorFixtures.topNotchCenter]),
            (FloorFixtures.convexCCW, [])
        ]

        for (polygon, excluded) in cases {
            let layout = Layout(name: "Hall", sizeM: SIMD2(20, 12), hall: polygon)

            let blocks = VenueGeometry.blocks(for: layout)
            let hallBlocks = blocks.filter { $0.color == VenueGeometry.hallFloorColor }

            #expect(hallBlocks.count == 1)
            let hallBlock = try #require(hallBlocks.first)
            guard case let .polygon(points) = hallBlock.shape else {
                Issue.record("Expected .polygon shape for hall floor, got \(hallBlock.shape)")
                return
            }
            #expect(points.count == polygon.count)
            for (actual, expected) in zip(points, polygon) {
                #expect(abs(Double(actual.x) - expected.x) < 1e-4)
                #expect(abs(Double(actual.y) - expected.y) < 1e-4)
            }

            let slab = MeshData.floorSlab(polygon: points, topY: 0, thickness: VenueGeometry.floorThickness)
            FloorChecks.verifyFloorSlab(
                slab,
                for: polygon,
                topY: 0,
                thickness: VenueGeometry.floorThickness,
                excludedPoints: excluded
            )
        }
    }

    @Test("VenueGeometry falls back to a bounding box floor when hall has fewer than three points")
    func venueGeometryFallsBackToBoxWhenHallTooShort() throws {
        let shortHalls: [[SIMD2<Double>]] = [[], [SIMD2(0, 0), SIMD2(20, 0)]]

        for hall in shortHalls {
            let layout = Layout(name: "Fallback", sizeM: SIMD2(20, 12), hall: hall)

            let blocks = VenueGeometry.blocks(for: layout)
            let hallBlock = try #require(blocks.first { $0.color == VenueGeometry.hallFloorColor })

            #expect(hallBlock.shape == .box)
            #expect(abs(hallBlock.center.x - 10) < 1e-4)
            #expect(abs(hallBlock.center.y - (-VenueGeometry.floorThickness / 2)) < 1e-4)
            #expect(abs(hallBlock.center.z - 6) < 1e-4)
            #expect(abs(hallBlock.size.x - 20) < 1e-4)
            #expect(abs(hallBlock.size.y - VenueGeometry.floorThickness) < 1e-4)
            #expect(abs(hallBlock.size.z - 12) < 1e-4)
        }
    }
}

private enum FloorFixtures {
    static let convexCCW: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 6), SIMD2(0, 6)
    ]
    static let convexCW = Array(convexCCW.reversed())

    static let notchedCCW: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(6, 0), SIMD2(6, 4), SIMD2(14, 4),
        SIMD2(14, 0), SIMD2(20, 0), SIMD2(20, 12), SIMD2(0, 12)
    ]
    static let notchedCW = Array(notchedCCW.reversed())

    static let doubleNotchedCCW: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(6, 0), SIMD2(6, 4), SIMD2(14, 4),
        SIMD2(14, 0), SIMD2(20, 0), SIMD2(20, 12), SIMD2(14, 12),
        SIMD2(14, 8), SIMD2(6, 8), SIMD2(6, 12), SIMD2(0, 12)
    ]
    static let doubleNotchedCW = Array(doubleNotchedCCW.reversed())

    static let collinearNotchedCCW: [SIMD2<Double>] = [
        SIMD2(0, 0), SIMD2(3, 0), SIMD2(6, 0), SIMD2(6, 4),
        SIMD2(10, 4), SIMD2(14, 4), SIMD2(14, 0), SIMD2(20, 0),
        SIMD2(20, 6), SIMD2(20, 12), SIMD2(10, 12), SIMD2(0, 12)
    ]
    static let collinearNotchedCW = Array(collinearNotchedCCW.reversed())

    static let topNotchCenter = SIMD2<Double>(10, 2)
    static let bottomNotchCenter = SIMD2<Double>(10, 10)
}

private enum FloorChecks {
    private typealias Triangle2D = (SIMD2<Double>, SIMD2<Double>, SIMD2<Double>)

    private struct SlabTriangle {
        let v0: MeshData.Vertex
        let v1: MeshData.Vertex
        let v2: MeshData.Vertex
    }

    static func verifyTriangulation(
        _ triangles: [(Int, Int, Int)],
        of polygon: [SIMD2<Double>],
        excludedPoints: [SIMD2<Double>] = []
    ) {
        let points2D: [Triangle2D] = triangles.map { idxA, idxB, idxC in
            #expect(idxA >= 0 && idxA < polygon.count)
            #expect(idxB >= 0 && idxB < polygon.count)
            #expect(idxC >= 0 && idxC < polygon.count)
            #expect(idxA != idxB && idxB != idxC && idxC != idxA)
            return (polygon[idxA], polygon[idxB], polygon[idxC])
        }
        verify2DTriangles(points2D, of: polygon, excludedPoints: excludedPoints, tolerance: 1e-4)
    }

    static func verifyTriangleMesh(
        _ mesh: TriangleMesh,
        for polygon: [SIMD2<Double>],
        heightY: Double,
        excludedPoints: [SIMD2<Double>] = []
    ) {
        #expect(mesh.indices.count % 3 == 0)
        #expect(mesh.triangleCount > 0)
        for (position, normal) in zip(mesh.positions, mesh.normals) {
            #expect(abs(Double(position.y) - heightY) < 1e-4)
            #expect(abs(normal.x) < 1e-4 && abs(normal.y - 1) < 1e-4 && abs(normal.z) < 1e-4)
        }
        let triangles2D: [Triangle2D] = stride(from: 0, to: mesh.indices.count, by: 3).map { start in
            let posA = mesh.positions[Int(mesh.indices[start])]
            let posB = mesh.positions[Int(mesh.indices[start + 1])]
            let posC = mesh.positions[Int(mesh.indices[start + 2])]
            #expect(simd_cross(posB - posA, posC - posA).y > 0)
            return (xzPoint(posA), xzPoint(posB), xzPoint(posC))
        }
        verify2DTriangles(triangles2D, of: polygon, excludedPoints: excludedPoints, tolerance: 1e-2)
    }

    static func verifyFloorSlab(
        _ mesh: MeshData,
        for polygon: [SIMD2<Double>],
        topY: Float,
        thickness: Float,
        excludedPoints: [SIMD2<Double>] = []
    ) {
        #expect(mesh.indices.count % 3 == 0)
        #expect(!mesh.indices.isEmpty)
        var top: [SlabTriangle] = []
        var bottom: [SlabTriangle] = []
        var rim: [SlabTriangle] = []
        let bottomY = topY - thickness

        for start in stride(from: 0, to: mesh.indices.count, by: 3) {
            let tri = SlabTriangle(
                v0: mesh.vertices[Int(mesh.indices[start])],
                v1: mesh.vertices[Int(mesh.indices[start + 1])],
                v2: mesh.vertices[Int(mesh.indices[start + 2])]
            )
            let verts = [tri.v0, tri.v1, tri.v2]
            if verts.allSatisfy({ abs($0.position.y - topY) < 1e-3 && $0.normal.y > 0.5 }) {
                top.append(tri)
            } else if verts.allSatisfy({ abs($0.position.y - bottomY) < 1e-3 && $0.normal.y < -0.5 }) {
                bottom.append(tri)
            } else {
                rim.append(tri)
            }
        }
        verifyCap(top, for: polygon, normalY: 1, excludedPoints: excludedPoints)
        verifyCap(bottom, for: polygon, normalY: -1, excludedPoints: excludedPoints)
        verifyRim(rim, for: polygon, thickness: thickness)
    }

    private static func verifyCap(
        _ triangles: [SlabTriangle],
        for polygon: [SIMD2<Double>],
        normalY: Float,
        excludedPoints: [SIMD2<Double>]
    ) {
        let triangles2D: [Triangle2D] = triangles.map { tri in
            for vertex in [tri.v0, tri.v1, tri.v2] {
                #expect(vertex.normal.y * normalY > 0.999)
                #expect(abs(simd_length(vertex.normal) - 1) < 1e-3)
            }
            let cross = simd_cross(tri.v1.position - tri.v0.position, tri.v2.position - tri.v0.position)
            #expect(cross.y * normalY > 0)
            return (xzPoint(tri.v0.position), xzPoint(tri.v1.position), xzPoint(tri.v2.position))
        }
        verify2DTriangles(triangles2D, of: polygon, excludedPoints: excludedPoints, tolerance: 0.02)
    }

    private static func verify2DTriangles(
        _ triangles: [Triangle2D],
        of polygon: [SIMD2<Double>],
        excludedPoints: [SIMD2<Double>] = [],
        tolerance: Double
    ) {
        #expect(!triangles.isEmpty)
        var totalArea = 0.0
        var expectedSign = 0.0

        for (ptA, ptB, ptC) in triangles {
            let twiceSigned = cross2D(ptB - ptA, ptC - ptA)
            #expect(abs(twiceSigned) > 1e-6)
            if expectedSign == 0 {
                expectedSign = twiceSigned > 0 ? 1 : -1
            } else {
                #expect(twiceSigned * expectedSign > 0)
            }
            let centroid = (ptA + ptB + ptC) / 3.0
            #expect(LayoutGeometry.polygonContains(polygon, point: centroid))
            for excluded in excludedPoints {
                #expect(!triangleContains(excluded, ptA, ptB, ptC))
            }
            totalArea += abs(twiceSigned) * 0.5
        }
        #expect(abs(totalArea - polygonArea(polygon)) < tolerance)
    }

    private static func xzPoint(_ point: SIMD3<Float>) -> SIMD2<Double> {
        SIMD2(Double(point.x), Double(point.z))
    }

    private static func verifyRim(_ triangles: [SlabTriangle], for polygon: [SIMD2<Double>], thickness: Float) {
        #expect(!triangles.isEmpty)
        var rimArea = 0.0
        for tri in triangles {
            for vertex in [tri.v0, tri.v1, tri.v2] {
                #expect(abs(vertex.normal.y) < 1e-3)
                #expect(abs(simd_length(vertex.normal) - 1) < 1e-3)
            }
            let cross = simd_cross(tri.v1.position - tri.v0.position, tri.v2.position - tri.v0.position)
            let wanted = tri.v0.normal + tri.v1.normal + tri.v2.normal
            #expect(simd_dot(cross, wanted) > 0)

            let center3D = (tri.v0.position + tri.v1.position + tri.v2.position) / 3
            let centroid = SIMD2<Double>(Double(center3D.x), Double(center3D.z))
            let normal2D = SIMD2<Double>(Double(tri.v0.normal.x), Double(tri.v0.normal.z))
            #expect(!LayoutGeometry.polygonContains(polygon, point: centroid + normal2D * 0.05))
            #expect(LayoutGeometry.polygonContains(polygon, point: centroid - normal2D * 0.05))

            rimArea += Double(simd_length(cross)) * 0.5
        }
        let expectedArea = polygonPerimeter(polygon) * Double(thickness)
        #expect(abs(rimArea - expectedArea) < 0.02)
    }

    private static func cross2D(_ first: SIMD2<Double>, _ second: SIMD2<Double>) -> Double {
        first.x * second.y - first.y * second.x
    }

    private static func polygonArea(_ polygon: [SIMD2<Double>]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        var sum = 0.0
        for index in polygon.indices {
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) * 0.5
    }

    private static func polygonPerimeter(_ polygon: [SIMD2<Double>]) -> Double {
        guard polygon.count >= 2 else { return 0 }
        var total = 0.0
        for index in polygon.indices {
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            total += simd_distance(current, next)
        }
        return total
    }

    private static func triangleContains(
        _ point: SIMD2<Double>,
        _ ptA: SIMD2<Double>,
        _ ptB: SIMD2<Double>,
        _ ptC: SIMD2<Double>
    ) -> Bool {
        let d1 = cross2D(ptB - ptA, point - ptA)
        let d2 = cross2D(ptC - ptB, point - ptB)
        let d3 = cross2D(ptA - ptC, point - ptC)
        let hasNeg = d1 < -1e-6 || d2 < -1e-6 || d3 < -1e-6
        let hasPos = d1 > 1e-6 || d2 > 1e-6 || d3 > 1e-6
        return !(hasNeg && hasPos)
    }
}

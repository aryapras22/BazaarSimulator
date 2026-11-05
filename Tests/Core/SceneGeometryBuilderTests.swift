import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct SceneGeometryBuilderTests {
    private let sampleLegend = Legend(entries: [
        LegendEntry(name: "Food & Beverage", color: LegendColor(red: 1, green: 0, blue: 0)),
        LegendEntry(name: "Fashion & Beauty", color: LegendColor(red: 0, green: 1, blue: 0)),
        LegendEntry(name: "Lifestyle & Hobbies", color: LegendColor(red: 0, green: 0, blue: 1))
    ])

    @Test("Beyond stays under 80,000 triangles")
    func beyondTriangleCount() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: sampleLegend)

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: sampleLegend)

        var totalTriangles = 0
        for (_, mesh) in geometry.meshes {
            totalTriangles += mesh.triangleCount
        }

        #expect(totalTriangles > 0)
        #expect(totalTriangles < 80000)
    }

    @Test("Every normal has unit length")
    func normalsAreUnitLength() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: sampleLegend)

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: sampleLegend)

        for (key, mesh) in geometry.meshes {
            for normal in mesh.normals {
                let len = simd_length(normal)
                #expect(abs(len - 1.0) < 0.001, "Normal for \(key.role) has non-unit length: \(len)")
            }
        }
    }

    @Test("Booth tints produce one mesh per category in use")
    func boothTintsProduceMeshPerCategory() throws {
        let cat1 = sampleLegend.entries[0]
        let cat2 = sampleLegend.entries[1]

        let booth1 = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: cat1.id,
            openSides: .bottom
        )
        let booth2 = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(10, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: cat2.id,
            openSides: .bottom
        )

        let layout = Layout(
            id: UUID(),
            name: "Tint Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: [SIMD2<Double>(0, 0), SIMD2<Double>(20, 0), SIMD2<Double>(20, 20), SIMD2<Double>(0, 20)],
            lobby: [],
            objects: [booth1, booth2],
            markers: [],
            zones: []
        )

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: sampleLegend)

        let fasciaKeys = geometry.meshes.keys.filter { $0.role == MaterialRole.fascia }
        #expect(fasciaKeys.count == 2)
        #expect(fasciaKeys.contains(SceneMaterialKey(role: .fascia, tint: cat1.color)))
        #expect(fasciaKeys.contains(SceneMaterialKey(role: .fascia, tint: cat2.color)))
    }

    @Test("A wall object leaves a gap under the lintel where its door is")
    func wallObjectHasDoorGap() {
        let (layout, _) = PerimeterWallsTests.wallWithCenteredDoor()

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: sampleLegend)

        let mesh = geometry.meshes[SceneMaterialKey(role: .wall, tint: nil)] ?? TriangleMesh()
        // A box only has vertices at its corners, so look for faces that cross the door center instead.
        // The door's own frame lintel sits just under the wall lintel, so only faces reaching 1 m count.
        let facesAcrossDoorway = stride(from: 0, to: mesh.indices.count, by: 3).filter { start in
            let corners = mesh.indices[start..<start + 3].map { mesh.positions[Int($0)] }
            let xValues = corners.map(\.x)
            return corners.allSatisfy { abs($0.z) < 0.5 }
                && (xValues.min() ?? 0) < 5.0 && (xValues.max() ?? 0) > 5.0
                && (corners.map(\.y).min() ?? 0) < 1.0
        }
        #expect(mesh.triangleCount > 0)
        #expect(facesAcrossDoorway.isEmpty)
    }

    @Test("A door without a catalog id still draws the default door")
    func doorWithoutCatalogIDIsDrawn() {
        let door = LayoutObject(
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2<Double>(5, 0), sizeM: SIMD2<Double>(1.2, 0.3))
        )
        let layout = Layout(name: "Door", sizeM: SIMD2<Double>(10, 10), objects: [door])

        let geometry = SceneGeometryBuilder.build(layout: layout, legend: sampleLegend)

        let nonAccentTriangles = geometry.meshes
            .filter { $0.key.role != .accent && $0.key.role != .floor }
            .map(\.value.triangleCount)
            .reduce(0, +)
        #expect(nonAccentTriangles > 0)
    }

    @Test("Floor polygon triangles face +Y up for clockwise, counter-clockwise, and mock halls")
    func floorPolygonTrianglesFaceUp() throws {
        func allTrianglesFaceUp(_ mesh: TriangleMesh) -> Bool {
            guard mesh.indices.count >= 3 else { return false }
            for start in stride(from: 0, to: mesh.indices.count, by: 3) {
                let idxA = Int(mesh.indices[start])
                let idxB = Int(mesh.indices[start + 1])
                let idxC = Int(mesh.indices[start + 2])
                let vertA = mesh.positions[idxA]
                let vertB = mesh.positions[idxB]
                let vertC = mesh.positions[idxC]
                let edge1 = vertB - vertA
                let edge2 = vertC - vertA
                let normalY = edge1.z * edge2.x - edge1.x * edge2.z
                if normalY <= 0 { return false }
            }
            return true
        }

        var ccwMesh = TriangleMesh()
        ccwMesh.appendFloorPolygon([
            SIMD2<Double>(0, 0),
            SIMD2<Double>(10, 0),
            SIMD2<Double>(10, 10),
            SIMD2<Double>(0, 10)
        ])
        #expect(allTrianglesFaceUp(ccwMesh))

        var cwMesh = TriangleMesh()
        cwMesh.appendFloorPolygon([
            SIMD2<Double>(0, 0),
            SIMD2<Double>(0, 10),
            SIMD2<Double>(10, 10),
            SIMD2<Double>(10, 0)
        ])
        #expect(allTrianglesFaceUp(cwMesh))

        let annyeongDTO = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let annyeongHall = annyeongDTO.hall.map { SIMD2<Double>($0[0], $0[1]) }
        var annyeongMesh = TriangleMesh()
        annyeongMesh.appendFloorPolygon(annyeongHall)
        #expect(allTrianglesFaceUp(annyeongMesh))

        let beyondDTO = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")
        let beyondHall = beyondDTO.hall.map { SIMD2<Double>($0[0], $0[1]) }
        var beyondMesh = TriangleMesh()
        beyondMesh.appendFloorPolygon(beyondHall)
        #expect(allTrianglesFaceUp(beyondMesh))
    }
}

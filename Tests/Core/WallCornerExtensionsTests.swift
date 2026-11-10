import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct WallCornerExtensionsTests {
    private static func makeWall(
        start: SIMD2<Double>,
        end: SIMD2<Double>,
        thickness: Double = 0.2
    ) -> LayoutObject {
        let vector = end - start
        let length = simd_length(vector)
        let center = (start + end) / 2.0
        let rotation = atan2(vector.y, vector.x)
        return LayoutObject(
            id: UUID(),
            kind: .wall,
            label: "Wall",
            placement: Placement(
                center: center,
                sizeM: SIMD2<Double>(length, thickness),
                rotationRadians: rotation
            ),
            catalogID: "wall",
            heightM: 3.0
        )
    }

    private static func makeLayout(objects: [LayoutObject]) -> Layout {
        Layout(
            name: "Test",
            sizeM: SIMD2<Double>(40, 40),
            hall: [
                SIMD2<Double>(0, 0),
                SIMD2<Double>(30, 0),
                SIMD2<Double>(30, 30),
                SIMD2<Double>(0, 30)
            ],
            objects: objects
        )
    }

    @Test("Two walls meeting at corner extend each other by half thickness")
    func cornerJoinExtendsByHalfThickness() throws {
        let wallA = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0), thickness: 0.2)
        let wallB = Self.makeWall(start: SIMD2<Double>(10, 0), end: SIMD2<Double>(10, 8), thickness: 0.4)
        let layout = Self.makeLayout(objects: [wallA, wallB])

        let extensions = WallCornerExtensions(layout: layout)
        let extA = extensions.extensions(for: wallA.id)
        let extB = extensions.extensions(for: wallB.id)

        #expect(abs(extA.start - 0.0) < 1e-4)
        #expect(abs(extA.end - 0.2) < 1e-4) // half of wallB's 0.4 thickness
        #expect(abs(extB.start - 0.1) < 1e-4) // half of wallA's 0.2 thickness
        #expect(abs(extB.end - 0.0) < 1e-4)

        let spansA = PerimeterWalls.spans(forWallObject: wallA, in: layout)
        let spanA = try #require(spansA.first)
        #expect(simd_distance(spanA.start, SIMD2<Double>(0, 0)) < 0.05)
        #expect(simd_distance(spanA.end, SIMD2<Double>(10.2, 0)) < 0.05)

        let spansB = PerimeterWalls.spans(forWallObject: wallB, in: layout)
        let spanB = try #require(spansB.first)
        #expect(simd_distance(spanB.start, SIMD2<Double>(10, -0.1)) < 0.05)
        #expect(simd_distance(spanB.end, SIMD2<Double>(10, 8)) < 0.05)
    }

    @Test("T-junction node needs no extension")
    func tJunctionNeedsNoExtension() throws {
        let hostWall = Self.makeWall(start: SIMD2<Double>(0, 0), end: SIMD2<Double>(10, 0), thickness: 0.2)
        let stemWall = Self.makeWall(start: SIMD2<Double>(5, 0), end: SIMD2<Double>(5, 5), thickness: 0.2)
        let layout = Self.makeLayout(objects: [hostWall, stemWall])

        let extensions = WallCornerExtensions(layout: layout)
        let hostExt = extensions.extensions(for: hostWall.id)
        let stemExt = extensions.extensions(for: stemWall.id)

        #expect(hostExt.start == 0.0)
        #expect(hostExt.end == 0.0)
        #expect(stemExt.start == 0.0)
        #expect(stemExt.end == 0.0)
    }
}

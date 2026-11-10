import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct SnapperTests {
    private func makeLayout(
        objects: [LayoutObject] = [],
        hall: [SIMD2<Double>] = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(20, 0),
            SIMD2<Double>(20, 20),
            SIMD2<Double>(0, 20)
        ]
    ) -> Layout {
        Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(20, 20),
            hall: hall,
            lobby: [],
            objects: objects,
            markers: []
        )
    }

    @Test("Priority order: wall endpoint beats grid and wall face even if both are within 10 pt")
    func wallEndpointBeatsWallFaceAndGrid() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.0, 0.0),
            sizeM: SIMD2<Double>(10.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let layout = makeLayout(objects: [wall], hall: [])

        let pointer = SIMD2<Double>(9.9, 0.05)
        let result = Snapper.snap(point: pointer, layout: layout, pointsPerMetre: 10.0)

        #expect(result.kind == .wallEndpoint)
        #expect(abs(result.point.x - 10.0) < 1e-4)
        #expect(abs(result.point.y - 0.0) < 1e-4)
    }

    @Test("Tolerance holding at two different zoom levels")
    func toleranceHoldingAtDifferentZoomLevels() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.0, 10.0),
            sizeM: SIMD2<Double>(10.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let layout = makeLayout(objects: [wall], hall: [])

        let pointer = SIMD2<Double>(10.5, 10.0)

        let result10 = Snapper.snap(point: pointer, layout: layout, pointsPerMetre: 10.0)
        #expect(result10.kind == .wallEndpoint)
        #expect(abs(result10.point.x - 10.0) < 1e-4)
        #expect(abs(result10.point.y - 10.0) < 1e-4)

        let result40 = Snapper.snap(point: pointer, layout: layout, pointsPerMetre: 40.0)
        #expect(result40.kind != .wallEndpoint)
        #expect(abs(result40.point.x - 10.5) < 1e-4)
        #expect(abs(result40.point.y - 10.0) < 1e-4)
    }

    @Test("Option key / free: true turns snapping off and produces no guides")
    func freeTurnsSnappingOff() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.0, 0.0),
            sizeM: SIMD2<Double>(10.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let layout = makeLayout(objects: [wall], hall: [])

        let pointer = SIMD2<Double>(9.9, 0.05)
        let result = Snapper.snap(point: pointer, layout: layout, pointsPerMetre: 10.0, isFree: true)

        #expect(result.kind == .none)
        #expect(result.guides.isEmpty)
        #expect(result.point == pointer)
    }

    @Test("Guides returned for alignment and wall snaps")
    func guidesReturnedForAlignmentAndWallSnaps() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.0, 0.0),
            sizeM: SIMD2<Double>(10.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let boothPlacement = Placement(
            center: SIMD2<Double>(5.0, 5.0),
            sizeM: SIMD2<Double>(2.0, 2.0),
            rotationRadians: 0
        )
        let booth = LayoutObject(kind: .booth, label: "Booth", placement: boothPlacement)
        let layout = makeLayout(objects: [wall, booth], hall: [])

        let wallPointer = SIMD2<Double>(5.0, 0.05)
        let wallResult = Snapper.snap(point: wallPointer, layout: layout, pointsPerMetre: 10.0)
        #expect(wallResult.kind == .wallBody)
        #expect(!wallResult.guides.isEmpty)
        #expect(wallResult.guides.first?.kind == .wallBody)

        let alignPointer = SIMD2<Double>(5.03, 12.0)
        let alignResult = Snapper.snap(point: alignPointer, layout: layout, pointsPerMetre: 10.0)
        #expect(alignResult.kind == .alignment)
        #expect(!alignResult.guides.isEmpty)
        #expect(alignResult.guides.first?.kind == .alignment)
        #expect(abs(alignResult.point.x - 5.0) < 1e-4)
    }

    @Test("Priority order: wallBody snaps to centerline between endpoints")
    func wallBodySnapsToCenterline() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(5.0, 0.0),
            sizeM: SIMD2<Double>(10.0, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall", placement: wallPlacement)
        let layout = makeLayout(objects: [wall], hall: [])

        let pointer = SIMD2<Double>(4.0, 0.15)
        let result = Snapper.snap(point: pointer, layout: layout, pointsPerMetre: 10.0)

        #expect(result.kind == .wallBody)
        #expect(abs(result.point.x - 4.0) < 1e-4)
        #expect(abs(result.point.y - 0.0) < 1e-4)
    }
}

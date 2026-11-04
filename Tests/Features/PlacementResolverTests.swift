import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct PlacementResolverTests {
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

    @Test("An item near a wall turns away from it and sits flush")
    func itemNearWallTurnsAwayAndSitsFlush() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(10, 5),
            sizeM: SIMD2<Double>(10, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall 1", placement: wallPlacement)
        let layout = makeLayout(objects: [wall])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(2, 2),
            at: SIMD2<Double>(10, 5.6),
            extraRotationDegrees: 0,
            kind: .fixture,
            in: layout,
            free: false
        )

        #expect(abs(candidate.placement.center.x - 10.0) < 1e-4)
        #expect(abs(candidate.placement.center.y - 6.1) < 1e-4)
        #expect(abs(candidate.placement.rotationRadians) < 1e-4)
        #expect(candidate.isValid)
    }

    @Test("Option disables the pull")
    func optionDisablesPull() {
        let wallPlacement = Placement(
            center: SIMD2<Double>(10, 5),
            sizeM: SIMD2<Double>(10, 0.2),
            rotationRadians: 0
        )
        let wall = LayoutObject(kind: .wall, label: "Wall 1", placement: wallPlacement)
        let layout = makeLayout(objects: [wall])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(2, 2),
            at: SIMD2<Double>(10, 5.6),
            extraRotationDegrees: 0,
            kind: .fixture,
            in: layout,
            free: true
        )

        #expect(abs(candidate.placement.center.x - 10.0) < 1e-4)
        #expect(abs(candidate.placement.center.y - 5.6) < 1e-4)
    }

    @Test("A booth template snaps flush to a neighbour's side")
    func boothFlushSnapExtendsRow() {
        let neighborPlacement = Placement(
            center: SIMD2<Double>(5, 5),
            sizeM: SIMD2<Double>(2, 2),
            rotationRadians: 0
        )
        let neighbor = LayoutObject(kind: .booth, label: "B1", placement: neighborPlacement)
        let layout = makeLayout(objects: [neighbor])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(2, 2),
            at: SIMD2<Double>(6.3, 5.0),
            extraRotationDegrees: 0,
            kind: .booth,
            in: layout,
            free: false
        )

        #expect(abs(candidate.placement.center.x - 7.0) < 1e-4)
        #expect(abs(candidate.placement.center.y - 5.0) < 1e-4)
        #expect(abs(candidate.placement.rotationRadians) < 1e-4)
        #expect(candidate.isValid)
    }

    @Test("Invalid when outside the walkable floor")
    func invalidOutsideFloor() {
        let layout = makeLayout()

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(2, 2),
            at: SIMD2<Double>(25, 25),
            extraRotationDegrees: 0,
            kind: .booth,
            in: layout,
            free: false
        )

        #expect(!candidate.isValid)
        #expect(candidate.note == "Outside floor bounds")
    }

    @Test("Invalid when overlapping a blocked area")
    func invalidOverlappingBlockedArea() {
        let areaPlacement = Placement(
            center: SIMD2<Double>(10, 10),
            sizeM: SIMD2<Double>(4, 4),
            rotationRadians: 0
        )
        let blockedArea = LayoutObject(kind: .closedArea, label: "Blocked", placement: areaPlacement)
        let layout = makeLayout(objects: [blockedArea])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(2, 2),
            at: SIMD2<Double>(10, 10),
            extraRotationDegrees: 0,
            kind: .table,
            in: layout,
            free: false
        )

        #expect(!candidate.isValid)
        #expect(candidate.note == "Overlaps blocked area")
    }

    @Test("A booth on top of another booth stays valid with an overlap note")
    func boothOnBoothWarns() {
        let booth = LayoutObject(
            kind: .booth,
            label: "N1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(3, 2))
        )
        let layout = makeLayout(objects: [booth])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(3, 2),
            at: SIMD2<Double>(10, 10),
            extraRotationDegrees: 0,
            kind: .booth,
            in: layout,
            free: true
        )

        #expect(candidate.isValid)
        #expect(candidate.note == "Overlaps N1")
    }

    @Test("A booth snapped flush to a neighbour has no overlap note")
    func flushBoothHasNoNote() {
        let booth = LayoutObject(
            kind: .booth,
            label: "N1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(3, 2))
        )
        let layout = makeLayout(objects: [booth])

        let candidate = PlacementResolver.resolve(
            size: SIMD2<Double>(3, 2),
            at: SIMD2<Double>(11.7, 10),
            extraRotationDegrees: 0,
            kind: .booth,
            in: layout,
            free: false
        )

        #expect(abs(candidate.placement.center.x - 13) < 1e-6)
        #expect(candidate.isValid)
        #expect(candidate.note == nil)
    }
}

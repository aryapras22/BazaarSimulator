import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutHitTesterTests {
    @Test("Topmost object wins when two objects overlap")
    func topmostObjectWins() {
        let block = LayoutObject(
            kind: .block,
            label: "K1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let door = LayoutObject(
            kind: .door,
            label: "D1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [block, door])

        let hitID = LayoutHitTester.object(at: SIMD2<Double>(10, 10), in: layout, layer: .structure)

        #expect(hitID == door.id)
    }

    @Test("A rotated booth is hit inside its rotated area and missed outside")
    func rotatedBoothHitTesting() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(
                center: SIMD2<Double>(10, 10),
                sizeM: SIMD2<Double>(2, 6),
                rotationRadians: .pi / 2
            )
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth])

        let hitInsideRotated = LayoutHitTester.object(at: SIMD2<Double>(12.5, 10), in: layout, layer: .booths)
        let missUnrotatedArea = LayoutHitTester.object(at: SIMD2<Double>(10, 12.5), in: layout, layer: .booths)

        #expect(hitInsideRotated == booth.id)
        #expect(missUnrotatedArea == nil)
    }

    @Test("Doors are hit on Structure and booths are hit on Booths")
    func layerFiltering() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2))
        )
        let door = LayoutObject(
            kind: .door,
            label: "Door A",
            placement: Placement(center: SIMD2<Double>(15, 15), sizeM: SIMD2<Double>(2, 0.4)),
            doorFlow: DoorFlow(direction: .entrance)
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth, door])

        #expect(LayoutHitTester.object(at: SIMD2<Double>(15, 15), in: layout, layer: .structure) == door.id)
        #expect(LayoutHitTester.object(at: SIMD2<Double>(5, 5), in: layout, layer: .structure) == nil)
        #expect(LayoutHitTester.object(at: SIMD2<Double>(5, 5), in: layout, layer: .booths) == booth.id)
        #expect(LayoutHitTester.object(at: SIMD2<Double>(15, 15), in: layout, layer: .booths) == nil)
    }

    @Test("A door is hit within its 0.3 m tolerance")
    func doorHitWithinTolerance() {
        let door = LayoutObject(
            kind: .door,
            label: "Door A",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 0.2)),
            doorFlow: DoorFlow(direction: .entrance)
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [door])

        let nearPoint = SIMD2<Double>(10, 10.35)
        let farPoint = SIMD2<Double>(10, 10.5)

        #expect(LayoutHitTester.object(at: nearPoint, in: layout, layer: .structure) == door.id)
        #expect(LayoutHitTester.object(at: farPoint, in: layout, layer: .structure) == nil)
    }

    @Test("Hit testing filters objects by active layer")
    func hitTestingFiltersByLayer() {
        let wall = LayoutObject(
            kind: .wall,
            label: "Wall 1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(4, 0.2))
        )
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [wall, booth])

        let hitStructure = LayoutHitTester.object(at: SIMD2<Double>(10, 10), in: layout, layer: .structure)
        let hitBooths = LayoutHitTester.object(at: SIMD2<Double>(10, 10), in: layout, layer: .booths)

        #expect(hitStructure == wall.id)
        #expect(hitBooths == booth.id)
    }

    @Test("Locked object returns hit object on the other layer")
    func lockedObjectDetection() {
        let wall = LayoutObject(
            kind: .wall,
            label: "Wall 1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(4, 0.2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [wall])

        let lockedWhenInBooths = LayoutHitTester.lockedObject(
            at: SIMD2<Double>(10, 10),
            in: layout,
            currentLayer: .booths
        )
        let lockedWhenInStructure = LayoutHitTester.lockedObject(
            at: SIMD2<Double>(10, 10),
            in: layout,
            currentLayer: .structure
        )

        #expect(lockedWhenInBooths?.id == wall.id)
        #expect(lockedWhenInStructure == nil)
    }
}

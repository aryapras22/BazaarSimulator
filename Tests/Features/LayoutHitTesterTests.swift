import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutHitTesterTests {
    @Test("Topmost object wins when two objects overlap")
    func topmostObjectWins() {
        let table = LayoutObject(
            kind: .table,
            label: "T1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [table, booth])

        let hitID = LayoutHitTester.object(at: SIMD2<Double>(10, 10), in: layout, tab: .floorPlan)

        #expect(hitID == booth.id)
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

        let hitInsideRotated = LayoutHitTester.object(at: SIMD2<Double>(12.5, 10), in: layout, tab: .floorPlan)
        let missUnrotatedArea = LayoutHitTester.object(at: SIMD2<Double>(10, 12.5), in: layout, tab: .floorPlan)

        #expect(hitInsideRotated == booth.id)
        #expect(missUnrotatedArea == nil)
    }

    @Test("Doors are skipped in Floor Plan and booths are skipped in Flow")
    func tabFiltering() {
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

        #expect(LayoutHitTester.object(at: SIMD2<Double>(15, 15), in: layout, tab: .floorPlan) == nil)
        #expect(LayoutHitTester.object(at: SIMD2<Double>(5, 5), in: layout, tab: .flow) == nil)
        #expect(LayoutHitTester.object(at: SIMD2<Double>(15, 15), in: layout, tab: .flow) == door.id)
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

        #expect(LayoutHitTester.object(at: nearPoint, in: layout, tab: .flow) == door.id)
        #expect(LayoutHitTester.object(at: farPoint, in: layout, tab: .flow) == nil)
    }
}

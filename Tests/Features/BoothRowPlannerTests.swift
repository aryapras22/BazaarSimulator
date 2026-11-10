import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("BoothRowPlanner Tests")
struct BoothRowPlannerTests {
    private func makeLayout(objects: [LayoutObject] = []) -> Layout {
        Layout(
            id: UUID(),
            name: "Test Layout",
            sizeM: SIMD2<Double>(30, 30),
            hall: [
                SIMD2<Double>(0, 0),
                SIMD2<Double>(30, 0),
                SIMD2<Double>(30, 30),
                SIMD2<Double>(0, 30)
            ],
            lobby: [],
            objects: objects,
            markers: []
        )
    }

    @Test("Slots along a 10m line divide evenly into 4 booths of 2.5m")
    func rowSlotsDivideEvenly() {
        let layout = makeLayout()
        let plan = BoothRowPlanner.planRow(
            from: SIMD2<Double>(2, 5),
            to: SIMD2<Double>(12, 5),
            boothSize: SIMD2<Double>(2.5, 2.5),
            in: layout
        )

        #expect(plan.booths.count == 4)
        #expect(plan.validCount == 4)
        #expect(plan.skippedCount == 0)
        #expect(plan.booths.allSatisfy { $0.openSides == .bottom })
    }

    @Test("A run that does not divide evenly drops the remainder")
    func rowRunUnevenDivision() {
        let layout = makeLayout()
        let plan = BoothRowPlanner.planRow(
            from: SIMD2<Double>(2, 5),
            to: SIMD2<Double>(9, 5),
            boothSize: SIMD2<Double>(2.5, 2.5),
            in: layout
        )

        #expect(plan.booths.count == 2)
    }

    @Test("A rotated line produces rotated booth placements")
    func rotatedRowPlacement() {
        let layout = makeLayout()
        let plan = BoothRowPlanner.planRow(
            from: SIMD2<Double>(5, 2),
            to: SIMD2<Double>(5, 12),
            boothSize: SIMD2<Double>(2.5, 2.5),
            in: layout
        )

        #expect(plan.booths.count == 4)
        for booth in plan.booths {
            #expect(booth.placement.rotationDegrees == 90)
        }
    }

    @Test("Blocked slots intersecting an obstacle are marked invalid")
    func blockedSlotsSkipped() {
        let wall = LayoutObject(
            kind: .wall,
            label: "Obstacle",
            placement: Placement(center: SIMD2<Double>(4.5, 6.25), sizeM: SIMD2<Double>(2.0, 0.5))
        )
        let layout = makeLayout(objects: [wall])

        let plan = BoothRowPlanner.planRow(
            from: SIMD2<Double>(2, 5),
            to: SIMD2<Double>(12, 5),
            boothSize: SIMD2<Double>(2.5, 2.5),
            in: layout
        )

        #expect(plan.booths.count == 4)
        #expect(plan.skippedCount >= 1)
        #expect(plan.validCount <= 3)
    }

    @Test("Fill produces double rows sharing a back with aisles between pairs")
    func fillDoubleRowsShareBack() {
        let layout = makeLayout()
        let plan = BoothRowPlanner.planFill(
            from: SIMD2<Double>(2, 2),
            to: SIMD2<Double>(12, 16),
            boothSize: SIMD2<Double>(2.5, 2.5),
            aisleWidthM: 2.0,
            in: layout
        )

        #expect(plan.booths.count >= 8)
        let topFacing = plan.booths.filter { $0.openSides == .top }
        let bottomFacing = plan.booths.filter { $0.openSides == .bottom }
        #expect(!topFacing.isEmpty)
        #expect(!bottomFacing.isEmpty)
    }
}

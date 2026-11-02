import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct OpenSideInferenceTests {
    private let defaultHall: [SIMD2<Double>] = [
        SIMD2<Double>(0, 0),
        SIMD2<Double>(20, 0),
        SIMD2<Double>(20, 20),
        SIMD2<Double>(0, 20)
    ]

    @Test("A lone booth in the hall is open on four sides")
    func loneBoothIsOpenEverywhere() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), hall: defaultHall, objects: [booth])

        let sides = OpenSideInference.infer(for: booth, in: layout)

        #expect(sides == .all)
    }

    @Test("Two booths back to back are closed on the shared side")
    func backToBackBooths() {
        let topBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 9), sizeM: SIMD2<Double>(2, 2))
        )
        let bottomBooth = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(10, 11), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [topBooth, bottomBooth]
        )

        let topSides = OpenSideInference.infer(for: topBooth, in: layout)
        let bottomSides = OpenSideInference.infer(for: bottomBooth, in: layout)

        #expect(topSides == [.top, .left, .right])
        #expect(bottomSides == [.bottom, .left, .right])
    }

    @Test("A booth against the hall edge is closed on that side")
    func boothAgainstHallEdge() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 1.1), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), hall: defaultHall, objects: [booth])

        let sides = OpenSideInference.infer(for: booth, in: layout)

        #expect(sides == [.bottom, .left, .right])
    }

    @Test("A booth next to a closed area or a rail is closed on that side")
    func boothNextToObstacle() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let closedArea = LayoutObject(
            kind: .closedArea,
            label: "Closed",
            placement: Placement(center: SIMD2<Double>(7.9, 10), sizeM: SIMD2<Double>(2, 4))
        )
        let rail = LayoutObject(
            kind: .rail,
            label: "Rail",
            placement: Placement(center: SIMD2<Double>(11.2, 10), sizeM: SIMD2<Double>(0.2, 4))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, closedArea, rail]
        )

        let sides = OpenSideInference.infer(for: booth, in: layout)

        #expect(sides == [.top, .bottom])
    }

    @Test("A rotated booth reports sides in its own frame")
    func rotatedBoothReportsOwnFrame() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(
                center: SIMD2<Double>(10, 10),
                sizeM: SIMD2<Double>(2, 2),
                rotationRadians: .pi / 2
            )
        )
        let rightNeighbourInWorld = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(12, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, rightNeighbourInWorld]
        )

        let sides = OpenSideInference.infer(for: booth, in: layout)

        // Rotated +90 degrees clockwise: local .top points to world +X (right).
        #expect(!sides.contains(.top))
        #expect(sides.contains(.right))
        #expect(sides.contains(.bottom))
        #expect(sides.contains(.left))
    }
}

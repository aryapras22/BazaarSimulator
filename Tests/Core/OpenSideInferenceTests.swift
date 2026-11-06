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
            kind: .block,
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

    @Test("On Annyeong, no booth has zero open sides")
    func annyeongBoothsHaveAtLeastOneOpenSide() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let legend = Legend(entries: [
            LegendEntry(name: "Food & Beverage", color: LegendColor(red: 1, green: 0, blue: 0))
        ])

        let layout = MockLayoutMapper.layout(from: dto, legend: legend)
        let booths = layout.objects.filter { $0.kind == .booth }

        #expect(!booths.isEmpty)
        #expect(booths.allSatisfy { !$0.openSides.isEmpty })
    }

    @Test("A 0.5 m booth with free space is open")
    func halfMetreBoothWithFreeSpaceIsOpen() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(0.5, 0.5))
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), hall: defaultHall, objects: [booth])

        let sides = OpenSideInference.infer(for: booth, in: layout)

        #expect(sides == .all)
    }

    @Test("Two overlapping obstacles on one side are counted once")
    func twoOverlappingObstaclesCountedOnce() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let obstacleA = LayoutObject(
            kind: .block,
            label: "F1",
            placement: Placement(center: SIMD2<Double>(9.5, 8.8), sizeM: SIMD2<Double>(1.0, 0.4))
        )
        let obstacleB = LayoutObject(
            kind: .block,
            label: "F2",
            placement: Placement(center: SIMD2<Double>(9.5, 8.8), sizeM: SIMD2<Double>(1.0, 0.4))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, obstacleA, obstacleB]
        )

        #expect(OpenSideInference.isSideOpen(.top, of: booth, in: layout))
    }

    @Test("An aisle booth with two clear sides gets the wider one")
    func aisleBoothGetsWiderClearSide() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let topBlocker = LayoutObject(
            kind: .booth,
            label: "Top",
            placement: Placement(center: SIMD2<Double>(10, 8), sizeM: SIMD2<Double>(2, 2))
        )
        let bottomBlocker = LayoutObject(
            kind: .booth,
            label: "Bottom",
            placement: Placement(center: SIMD2<Double>(10, 12), sizeM: SIMD2<Double>(2, 2))
        )
        let leftWall = LayoutObject(
            kind: .wall,
            label: "WallLeft",
            placement: Placement(center: SIMD2<Double>(8.2, 10), sizeM: SIMD2<Double>(0.2, 4))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, topBlocker, bottomBlocker, leftWall]
        )

        let defaultSide = OpenSideInference.defaultSide(for: booth, in: layout)
        #expect(defaultSide == .right)
    }

    @Test("A corner booth gets one side")
    func cornerBoothGetsOneSide() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(1.1, 1.1), sizeM: SIMD2<Double>(2, 2))
        )
        let bottomBlocker = LayoutObject(
            kind: .booth,
            label: "Bottom",
            placement: Placement(center: SIMD2<Double>(1.1, 3.1), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, bottomBlocker]
        )

        let defaultSide = OpenSideInference.defaultSide(for: booth, in: layout)
        #expect(defaultSide == .right)
    }

    @Test("A boxed-in booth gets none")
    func boxedInBoothGetsNone() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(10, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let top = LayoutObject(
            kind: .booth, label: "T", placement: Placement(center: SIMD2<Double>(10, 8), sizeM: SIMD2<Double>(2, 2))
        )
        let bottom = LayoutObject(
            kind: .booth, label: "B", placement: Placement(center: SIMD2<Double>(10, 12), sizeM: SIMD2<Double>(2, 2))
        )
        let left = LayoutObject(
            kind: .booth, label: "L", placement: Placement(center: SIMD2<Double>(8, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let right = LayoutObject(
            kind: .booth, label: "R", placement: Placement(center: SIMD2<Double>(12, 10), sizeM: SIMD2<Double>(2, 2))
        )
        let layout = Layout(
            name: "Test",
            sizeM: SIMD2<Double>(20, 20),
            hall: defaultHall,
            objects: [booth, top, bottom, left, right]
        )

        let defaultSide = OpenSideInference.defaultSide(for: booth, in: layout)
        #expect(defaultSide.isEmpty)
    }
}

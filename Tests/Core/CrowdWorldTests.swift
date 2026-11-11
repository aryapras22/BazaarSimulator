import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("CrowdWorld Tests")
@MainActor
struct CrowdWorldTests {

    @Test("Doors are carved through walls that otherwise block the floor")
    func doorsAreCarved() {
        let world = CrowdWorld(layout: PreviewLayouts.smallMarket())

        #expect(world.isFree(SIMD2(14.0, 20.1)))
        #expect(!world.isFree(SIMD2(19.5, 20.1)))
    }

    @Test("A rotated wall thinner than a cell still blocks the floor")
    func thinRotatedWallBlocks() {
        let wall = LayoutObject(
            kind: .wall,
            label: "Diagonal",
            placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(30, 0.1), rotationRadians: .pi / 4)
        )
        let world = CrowdWorld(layout: Self.floorLayout(objects: [wall]))
        let field = world.flowField(to: .exit)

        #expect(field.costs[world.cell(at: SIMD2(2, 18))] == .infinity)
        #expect(field.costs[world.cell(at: SIMD2(18, 2))] < .infinity)
    }

    @Test("A flow field walks around an obstacle toward its target")
    func flowFieldRoutesAroundObstacle() {
        let world = CrowdWorld(layout: Self.floorLayout(objects: [Self.block(center: SIMD2(9, 2.5), size: SIMD2(1, 3.5))]))
        let field = world.flowField(to: .exit)

        var position = SIMD2(4.0, 2.0)
        for _ in 0..<400 where field.costs[world.cell(at: position)] > 0 {
            #expect(world.isFree(position))
            position += field.direction(atCell: world.cell(at: position)) * 0.1
        }

        #expect(simd_distance(position, SIMD2(18, 2)) < 1.0)
    }

    @Test("Booths behind a closed ring of blocks are unreachable")
    func enclosedBoothIsUnreachable() {
        let booth = Self.booth(at: SIMD2(10, 10))
        let world = CrowdWorld(layout: Self.floorLayout(objects: [
            booth,
            Self.block(center: SIMD2(10, 14.5), size: SIMD2(10, 1)),
            Self.block(center: SIMD2(10, 5.5), size: SIMD2(10, 1)),
            Self.block(center: SIMD2(5.5, 10), size: SIMD2(1, 10)),
            Self.block(center: SIMD2(14.5, 10), size: SIMD2(1, 10))
        ]))

        #expect(!world.booths[0].isReachable(fromGate: 0))
    }

    @Test("An exit-only door is closed to inbound routes", arguments: [DoorDirection.exit, .both])
    func exitOnlyDoorBlocksInbound(direction: DoorDirection) {
        let world = CrowdWorld(layout: Self.twoRooms(door: direction))

        #expect(world.booths[0].isReachable(fromGate: 0) == (direction == .both))
    }

    @Test("A visitor standing in a one-way door still has a way out of it")
    func oneWayDoorCellHasRouteOut() {
        let world = CrowdWorld(layout: Self.twoRooms(door: .exit))
        let field = world.flowField(to: .booth(0))

        #expect(field.costs[world.cell(at: SIMD2(10, 10))].isFinite)
        #expect(!field.costs[world.cell(at: SIMD2(10, 15))].isFinite)
    }

    @Test("Booth type and pull come from the legend and attractiveness")
    func boothTypeAndPull() {
        let food = LegendEntry(name: "Food", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        let goods = LegendEntry(name: "Goods", color: LegendColor(red: 0, green: 1, blue: 0), type: .goods)
        var foodBooth = Self.booth(at: SIMD2(6, 6))
        foodBooth.categoryID = food.id
        foodBooth.attractiveness = 9
        var goodsBooth = Self.booth(at: SIMD2(12, 6), size: SIMD2(1, 1))
        goodsBooth.categoryID = goods.id

        let world = CrowdWorld(
            layout: Self.floorLayout(objects: [foodBooth, goodsBooth]),
            legend: Legend(entries: [food, goods])
        )

        #expect(world.booths[0].isFood)
        #expect(world.booths[0].pull == 5)
        #expect(world.booths[0].footprint.halfSize == SIMD2(1, 1))
        #expect(!world.booths[1].isFood)
        #expect(abs(world.booths[1].footprint.halfSize.x - 1.0) < 0.001)
    }

    private static func floorLayout(objects: [LayoutObject]) -> Layout {
        Layout(
            name: "Floor",
            sizeM: SIMD2(20, 20),
            hall: [],
            lobby: [],
            objects: objects,
            markers: [
                LayoutMarker(kind: .spawn, label: "In", position: SIMD2(2, 2)),
                LayoutMarker(kind: .exit, label: "Out", position: SIMD2(18, 2))
            ],
            zones: []
        )
    }

    /// Hall on y 1...9.9, lobby on y 10.1...19, joined by one door in the wall between them.
    private static func twoRooms(door direction: DoorDirection) -> Layout {
        let hall = [SIMD2(1.0, 1), SIMD2(19, 1), SIMD2(19, 9.9), SIMD2(1, 9.9)]
        let lobby = [SIMD2(1.0, 10.1), SIMD2(19, 10.1), SIMD2(19, 19), SIMD2(1, 19)]
        let door = LayoutObject(
            kind: .door,
            label: "Door",
            placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(2, 0.5)),
            doorFlow: DoorFlow(direction: direction, connection: .hallToLobby)
        )
        return Layout(
            name: "Two rooms",
            sizeM: SIMD2(20, 20),
            hall: hall,
            lobby: lobby,
            objects: [
                LayoutObject(kind: .wall, label: "Wall", placement: Placement(center: SIMD2(10, 10), sizeM: SIMD2(20, 0.2))),
                door,
                booth(at: SIMD2(10, 4))
            ],
            markers: [
                LayoutMarker(kind: .spawn, label: "In", position: SIMD2(4, 16)),
                LayoutMarker(kind: .exit, label: "Out", position: SIMD2(16, 16))
            ],
            zones: []
        )
    }

    private static func block(center: SIMD2<Double>, size: SIMD2<Double>) -> LayoutObject {
        LayoutObject(kind: .block, label: "Block", placement: Placement(center: center, sizeM: size))
    }

    private static func booth(at center: SIMD2<Double>, size: SIMD2<Double> = SIMD2(2, 2)) -> LayoutObject {
        LayoutObject(kind: .booth, label: "Booth", placement: Placement(center: center, sizeM: size))
    }
}

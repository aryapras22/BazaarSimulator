import simd
import Testing
@testable import BazaarSimulator

@Suite
struct NavigationGridTests {
    @Test("Floor is walkable and booths are not")
    func floorAndBooths() throws {
        let grid = NavigationGrid(layout: TestLayouts.hall())
        let floor = try #require(grid.cellIndex(for: SIMD2(12, 8)))
        let booth = try #require(grid.cellIndex(for: SIMD2(4, 2.5)))
        let outside = try #require(grid.cellIndex(for: SIMD2(-0.7, 6)))
        #expect(grid.walkable[floor])
        #expect(!grid.walkable[booth])
        #expect(!grid.walkable[outside])
    }

    @Test("A door cuts a way through a wall")
    func doorThroughWall() throws {
        var layout = TestLayouts.hall()
        layout.objects.append(LayoutObject(
            kind: .wall, label: "Wall",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(0.4, 12))
        ))
        layout.objects.append(LayoutObject(
            kind: .door, label: "Inner",
            placement: Placement(center: SIMD2(12, 8), sizeM: SIMD2(0.4, 2)),
            doorFlow: DoorFlow(direction: .both)
        ))
        let grid = NavigationGrid(layout: layout)
        let wall = try #require(grid.cellIndex(for: SIMD2(12, 3)))
        let door = try #require(grid.cellIndex(for: SIMD2(12, 8)))
        #expect(!grid.walkable[wall])
        #expect(grid.walkable[door])
        #expect(grid.doorIndex[door] >= 0)

        let field = grid.distanceField(from: [try #require(grid.cellIndex(for: SIMD2(1, 6)))])
        #expect(field[try #require(grid.cellIndex(for: SIMD2(20, 8)))] != Int32.max)
        #expect(field[try #require(grid.cellIndex(for: SIMD2(20, 5)))] != Int32.max)
    }

    @Test("A disabled door stays closed")
    func disabledDoor() throws {
        var layout = TestLayouts.hall()
        layout.objects.append(LayoutObject(
            kind: .wall, label: "Wall",
            placement: Placement(center: SIMD2(12, 6), sizeM: SIMD2(0.4, 12))
        ))
        layout.objects.append(LayoutObject(
            kind: .door, label: "Inner",
            placement: Placement(center: SIMD2(12, 8), sizeM: SIMD2(0.4, 2)),
            doorFlow: DoorFlow(direction: .disabled)
        ))
        let grid = NavigationGrid(layout: layout)
        let field = grid.distanceField(from: [try #require(grid.cellIndex(for: SIMD2(1, 6)))])
        #expect(field[try #require(grid.cellIndex(for: SIMD2(20, 8)))] == Int32.max)
    }

    @Test("A booth is reached from the cells in front of its open side")
    func boothAccess() throws {
        let layout = TestLayouts.hall()
        let grid = NavigationGrid(layout: layout)
        let booth = try #require(layout.objects.first { $0.kind == .booth })
        let access = grid.accessCells(of: booth)
        #expect(!access.isEmpty)
        #expect(access.allSatisfy { grid.walkable[$0] })
        #expect(access.allSatisfy { grid.center(of: $0).y > 3.4 })
    }

    @Test("Walking follows the field down to the target")
    func walkingFollowsField() throws {
        let grid = NavigationGrid(layout: TestLayouts.hall())
        let target = try #require(grid.cellIndex(for: SIMD2(20, 9)))
        let field = grid.distanceField(from: [target])
        var cell = try #require(grid.cellIndex(for: SIMD2(1, 6)))
        var steps = 0
        while field[cell] != 0, let next = grid.nextCell(from: cell, in: field), steps < 500 {
            cell = next
            steps += 1
        }
        #expect(cell == target)
        #expect(steps < 100)
    }

    @Test("The nearest walkable cell is found for a point just off the floor")
    func nearestWalkable() throws {
        let grid = NavigationGrid(layout: TestLayouts.hall())
        let cell = try #require(grid.nearestWalkableCell(to: SIMD2(-0.3, 6)))
        #expect(grid.walkable[cell])
    }
}

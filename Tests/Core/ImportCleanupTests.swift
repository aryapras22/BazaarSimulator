import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct ImportCleanupTests {
    private var legend: Legend { Legend(entries: []) }

    private func item(_ cls: String, _ box: [Double], kind: String? = nil) -> DetectedItem {
        DetectedItem(cls: cls, box: box, kind: kind)
    }

    private func wall(_ left: Double, _ right: Double) -> DetectedItem {
        DetectedItem(cls: "wall", box: [left, 0, right - left, 2], segment: [left, 0, right, 0], widthPx: 2)
    }

    private func layoutOf(_ items: [DetectedItem]) -> Layout {
        ExtractedLayoutMapper.layout(from: DetectedPlan(items: items), legend: legend, pixelsPerMetre: 10, name: "Plan")
    }

    private func tableWithChairs(at left: Double) -> [DetectedItem] {
        [
            item("object", [left, 0, 20, 20], kind: "chair_group"),
            item("object", [left + 6, 6, 8, 8], kind: "table"),
            item("object", [left + 8, 0, 4, 4], kind: "chair"),
            item("object", [left + 8, 16, 4, 4], kind: "chair")
        ]
    }

    @Test("Tables whose chairs touch are pushed apart, and tables already clear stay put")
    func tablesGetRoomForChairs() {
        let crowded = layoutOf(tableWithChairs(at: 0) + tableWithChairs(at: 21))
        let tables = crowded.objects.filter { $0.kind == .table }
        let apart = abs(tables[0].placement.center.x - tables[1].placement.center.x)
        #expect(apart > 2.1)
        for table in tables {
            let chairs = FurnitureModels.chairs(of: table)
            #expect(tables.filter { $0.id != table.id }.allSatisfy { other in
                !FurnitureModels.chairs(of: other).contains { chair in
                    chairs.contains { LayoutGeometry.intersects($0, chair) }
                }
            })
        }

        let roomy = layoutOf(tableWithChairs(at: 0) + tableWithChairs(at: 80))
        let roomyTables = roomy.objects.filter { $0.kind == .table }
        #expect(abs(roomyTables[0].placement.center.x - roomyTables[1].placement.center.x) == 8)
    }

    @Test("A window frame line beside a wall and a thin tick mark are dropped, a real wall stays")
    func wallNoiseIsDropped() {
        let layout = layoutOf([
            DetectedItem(cls: "wall", box: [0, 0, 300, 3], segment: [0, 0, 300, 0], symbolClass: "wall.thick"),
            DetectedItem(cls: "wall", box: [50, 12, 80, 1], segment: [50, 12, 130, 12], symbolClass: "wall.thin"),
            DetectedItem(cls: "wall", box: [500, 100, 20, 1], segment: [500, 100, 520, 100], symbolClass: "wall.thin")
        ])

        #expect(layout.objects.filter { $0.kind == .wall }.count == 1)
    }

    @Test("A wall that stops short of a corner is stretched to meet the other wall")
    func cornersMeet() throws {
        let layout = layoutOf([
            wall(0, 200),
            DetectedItem(cls: "wall", box: [0, 5, 2, 150], segment: [1, 5, 1, 155], widthPx: 2)
        ])

        let vertical = try #require(layout.objects.first { abs(sin($0.placement.rotationRadians)) > 0.9 })
        let top = vertical.placement.center.y - vertical.placement.sizeM.x / 2
        #expect(abs(top - 1) < 0.01)
    }

    @Test("A door lies in its wall, and one too narrow to pass is dropped")
    func doorsSeatInWalls() throws {
        let layout = layoutOf([
            wall(0, 300),
            DetectedItem(cls: "opening", box: [100, -2, 30, 6]),
            DetectedItem(cls: "opening", box: [200, -2, 5, 6])
        ])

        let doors = layout.objects.filter { $0.kind == .door }
        let door = try #require(doors.first)
        let host = try #require(layout.objects.first { $0.kind == .wall })
        #expect(doors.count == 1)
        #expect(door.placement.rotationRadians == 0)
        #expect(abs(door.placement.center.y - host.placement.center.y) < 0.001)
    }

    @Test("A wall and a door that connect to nothing are dropped once other walls are connected")
    func floatingWallsAndDoorsAreDropped() {
        let layout = layoutOf([
            wall(0, 300),
            DetectedItem(cls: "wall", box: [0, 0, 2, 200], segment: [1, 0, 1, 200], widthPx: 2),
            DetectedItem(cls: "wall", box: [900, 900, 200, 2], segment: [900, 900, 1100, 900], widthPx: 2),
            DetectedItem(cls: "opening", box: [100, -2, 30, 6]),
            DetectedItem(cls: "opening", box: [900, 700, 30, 6])
        ])

        #expect(layout.objects.filter { $0.kind == .wall }.count == 2)
        #expect(layout.objects.filter { $0.kind == .door }.count == 1)
    }

    @Test("A door further along a wall's own line stays, and one beside that line is dropped")
    func doorOnWallLinePastItsEndStays() {
        let layout = layoutOf([
            wall(0, 300),
            DetectedItem(cls: "wall", box: [0, 0, 2, 200], segment: [1, 0, 1, 200], widthPx: 2),
            DetectedItem(cls: "opening", box: [350, -2, 25, 6]),
            DetectedItem(cls: "opening", box: [350, 25, 25, 6])
        ])

        let doors = layout.objects.filter { $0.kind == .door }
        let host = layout.objects.first { $0.kind == .wall && $0.placement.rotationRadians == 0 }
        #expect(doors.count == 1)
        #expect(doors.first?.placement.center.y == host?.placement.center.y)
    }

    @Test("A door in the middle of a wall gap stays and lies on the wall line")
    func doorInGapStays() {
        let layout = layoutOf([
            wall(0, 100),
            wall(160, 300),
            DetectedItem(cls: "opening", box: [105, -2, 50, 6])
        ])

        #expect(layout.objects.filter { $0.kind == .door }.count == 1)
    }

    @Test("Two parallel walls on top of each other become one thick wall")
    func stackedWallsBecomeOne() throws {
        let layout = layoutOf([
            wall(0, 300),
            DetectedItem(cls: "wall", box: [0, 8, 300, 2], segment: [0, 8, 300, 8], widthPx: 2),
            DetectedItem(cls: "wall", box: [0, 0, 2, 100], segment: [1, 0, 1, 100], widthPx: 2)
        ])

        let walls = layout.objects.filter { $0.kind == .wall }
        #expect(walls.count == 2)
        let thick = try #require(walls.first { abs($0.placement.sizeM.x - 30) < 0.01 })
        #expect(abs(thick.placement.sizeM.y - 1.0) < 0.01)
    }

    @Test("A wall piece beside a door stays, so the door has a wall on each side")
    func wallBesideDoorStays() {
        let layout = layoutOf([
            wall(0, 100),
            wall(150, 175),
            wall(300, 400),
            DetectedItem(cls: "opening", box: [100, -2, 50, 6]),
            DetectedItem(cls: "opening", box: [175, -2, 125, 6])
        ])

        #expect(layout.objects.filter { $0.kind == .wall }.count == 3)
    }

    @Test("A wall is stretched up to a door that has no wall on one side")
    func wallReachesDoor() throws {
        let layout = layoutOf([
            wall(0, 100),
            DetectedItem(cls: "wall", box: [0, 0, 2, 100], segment: [1, 0, 1, 100], widthPx: 2),
            DetectedItem(cls: "opening", box: [100, -2, 50, 6])
        ])

        let walls = layout.objects.filter { $0.kind == .wall }
        let door = try #require(layout.objects.first { $0.kind == .door })
        let reach = walls.map { $0.placement.center.x + $0.placement.sizeM.x / 2 }.max() ?? 0
        #expect(abs(reach - (door.placement.center.x - door.placement.sizeM.x / 2)) < 0.05)
    }
}

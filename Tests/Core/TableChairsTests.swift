import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct TableChairsTests {
    @Test("Two chairs on a wide table sit on the two long sides")
    func twoChairsWideTable() {
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(2.0, 1.0), rotationRadians: 0)
        let chairs = TableChairs.chairPlacements(for: table, count: 2)

        #expect(chairs.count == 2)
        #expect(abs(chairs[0].center.x - 10.0) < 1e-4)
        #expect(chairs[0].center.y > 10.5)
        #expect(abs(chairs[1].center.x - 10.0) < 1e-4)
        #expect(chairs[1].center.y < 9.5)
    }

    @Test("Two chairs on a square table sit on opposite sides")
    func twoChairsSquareTable() {
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(1.0, 1.0), rotationRadians: 0)
        let chairs = TableChairs.chairPlacements(for: table, count: 2)

        #expect(chairs.count == 2)
        #expect(abs(chairs[0].center.x - 10.0) < 1e-4)
        #expect(chairs[0].center.y > 10.5)
        #expect(abs(chairs[1].center.x - 10.0) < 1e-4)
        #expect(chairs[1].center.y < 9.5)
    }

    @Test("Two chairs on a tall table sit on the long sides")
    func twoChairsTallTable() {
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(1.0, 3.0), rotationRadians: 0)
        let chairs = TableChairs.chairPlacements(for: table, count: 2)

        #expect(chairs.count == 2)
        #expect(abs(chairs[0].center.y - 10.0) < 1e-4)
        #expect(chairs[0].center.x < 9.5)
        #expect(abs(chairs[1].center.y - 10.0) < 1e-4)
        #expect(chairs[1].center.x > 10.5)
    }

    @Test("Four chairs take one chair per side")
    func fourChairsTable() {
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(2.0, 1.0), rotationRadians: 0)
        let chairs = TableChairs.chairPlacements(for: table, count: 4)

        #expect(chairs.count == 4)
        let xCoords = chairs.map { $0.center.x }
        let yCoords = chairs.map { $0.center.y }
        #expect(xCoords.contains { $0 > 11.0 })
        #expect(xCoords.contains { $0 < 9.0 })
        #expect(yCoords.contains { $0 > 10.5 })
        #expect(yCoords.contains { $0 < 9.5 })
    }

    @Test("A rotated table transforms chair placements to world coordinates")
    func rotatedTableChairs() {
        let angle = Double.pi / 2.0
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(2.0, 1.0), rotationRadians: angle)
        let chairs = TableChairs.chairPlacements(for: table, count: 2)

        #expect(chairs.count == 2)
        #expect(abs(chairs[0].center.y - 10.0) < 1e-4)
        #expect(abs(chairs[1].center.y - 10.0) < 1e-4)
        #expect(abs(chairs[0].center.x - 10.0) > 0.5)
        #expect(abs(chairs[1].center.x - 10.0) > 0.5)
    }

    @Test("Invalid chair counts return no placements")
    func invalidChairCounts() {
        let table = Placement(center: SIMD2(10, 10), sizeM: SIMD2(1.0, 1.0), rotationRadians: 0)
        #expect(TableChairs.chairPlacements(for: table, count: 0).isEmpty)
        #expect(TableChairs.chairPlacements(for: table, count: 6).isEmpty)
    }
}

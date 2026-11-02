import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct MockLayoutMapperTests {
    private let sampleLegend = Legend(entries: [
        LegendEntry(name: "Food & Beverage", color: LegendColor(red: 1, green: 0, blue: 0)),
        LegendEntry(name: "Fashion & Beauty", color: LegendColor(red: 0, green: 1, blue: 0))
    ])

    @Test("Annyeong maps to expected counts of every object kind, markers, and zones")
    func annyeongCounts() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")

        let layout = MockLayoutMapper.layout(from: dto, legend: sampleLegend)

        #expect(count(.booth, in: layout) == 209)
        #expect(count(.table, in: layout) == 26)
        #expect(count(.door, in: layout) == 4)
        #expect(count(.closedArea, in: layout) == 4)
        #expect(count(.stage, in: layout) == 1)
        #expect(count(.audienceArea, in: layout) == 1)
        #expect(count(.rail, in: layout) == 3)
        #expect(count(.wall, in: layout) == 3)
        #expect(count(.fixture, in: layout) == 1)
        #expect(layout.markers.count == 2)
        #expect(layout.zones.count == 2)

        let stage = try #require(layout.objects.first { $0.kind == .stage })
        #expect(stage.openSides == .left)

        let audience = try #require(layout.objects.first { $0.kind == .audienceArea })
        #expect(audience.label == "AUDIENCE")
    }

    @Test("Beyond maps to expected counts and stage extensions")
    func beyondCounts() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")

        let layout = MockLayoutMapper.layout(from: dto, legend: sampleLegend)

        #expect(count(.booth, in: layout) == 154)
        #expect(count(.table, in: layout) == 136)
        #expect(count(.door, in: layout) == 4)
        #expect(count(.closedArea, in: layout) == 6)
        #expect(count(.pillar, in: layout) == 23)
        #expect(count(.block, in: layout) == 3)
        #expect(count(.rail, in: layout) == 3)
        #expect(count(.wall, in: layout) == 3)
        #expect(count(.stage, in: layout) == 2)
        #expect(count(.fixture, in: layout) == 5)
        #expect(layout.zones.isEmpty)

        let mainStage = try #require(layout.objects.first { $0.kind == .stage && $0.label == "Stage" })
        #expect(mainStage.openSides == .bottom)
        #expect(layout.objects.contains { $0.kind == .stage && $0.label == "EXT" })
    }

    @Test("A rect maps to the right center and size")
    func rectMapsToCenterAndSize() {
        let rect = BazaarRectDTO(minX: 10.0, maxX: 16.0, minY: 20.0, maxY: 24.0)

        let placement = MockLayoutMapper.placement(from: rect)

        #expect(placement.center == SIMD2<Double>(13.0, 22.0))
        #expect(placement.sizeM == SIMD2<Double>(6.0, 4.0))
    }

    @Test("An outer door keeps its along-wall length as width and maps direction from nearest marker")
    func outerDoorKeepsAlongWallWidth() throws {
        let dto = try TestFixtureLoader.load(BazaarLayoutDTO.self, from: "small-layout")

        let layout = MockLayoutMapper.layout(from: dto, legend: sampleLegend)
        let outerDoors = layout.objects.filter {
            $0.kind == .door && $0.doorFlow?.connection == .lobbyToOutside
        }

        #expect(outerDoors.count == 2)
        let first = try #require(outerDoors.first { $0.label == "Outer Door 1" })
        let second = try #require(outerDoors.first { $0.label == "Outer Door 2" })

        #expect(abs(first.placement.sizeM.x - 2.0) < 1e-6)
        #expect(first.placement.rotationDegrees == 90)
        #expect(first.doorFlow?.direction == .entrance)
        #expect(second.doorFlow?.direction == .exit)
    }

    private func count(_ kind: LayoutObjectKind, in layout: Layout) -> Int {
        layout.objects.filter { $0.kind == kind }.count
    }
}

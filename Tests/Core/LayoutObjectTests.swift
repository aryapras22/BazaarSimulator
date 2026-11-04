import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutObjectTests {
    @Test("LayoutObject decodes legacy JSON without catalogID and heightM")
    func legacyDecodingWithoutCatalogIDAndHeight() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "kind": "booth",
            "label": "B1",
            "placement": {
                "center": [10.0, 15.0],
                "sizeM": [2.5, 2.5],
                "rotationRadians": 0.0
            },
            "openSides": 4,
            "reviewState": "confirmed"
        }
        """

        let data = try #require(json.data(using: .utf8))
        let object = try JSONDecoder().decode(LayoutObject.self, from: data)

        #expect(object.catalogID == nil)
        #expect(object.heightM == nil)
        #expect(object.label == "B1")
        #expect(object.kind == .booth)
    }

    @Test("LayoutObject decodes JSON with catalogID and heightM")
    func decodingWithCatalogIDAndHeight() throws {
        let json = """
        {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "kind": "table",
            "label": "T1",
            "placement": {
                "center": [5.0, 5.0],
                "sizeM": [1.0, 1.0],
                "rotationRadians": 0.0
            },
            "openSides": 0,
            "reviewState": "confirmed",
            "catalogID": "table-round-4",
            "heightM": 0.75
        }
        """

        let data = try #require(json.data(using: .utf8))
        let object = try JSONDecoder().decode(LayoutObject.self, from: data)

        #expect(object.catalogID == "table-round-4")
        #expect(object.heightM == 0.75)
    }

    @Test("LayoutObjectKind canBeAdded includes structural objects and movable doors")
    func addedKindsAndMovableDoors() {
        #expect(LayoutObjectKind.wall.canBeAdded)
        #expect(LayoutObjectKind.block.canBeAdded)
        #expect(LayoutObjectKind.pillar.canBeAdded)
        #expect(LayoutObjectKind.stage.canBeAdded)
        #expect(LayoutObjectKind.door.canBeAdded)
        #expect(LayoutObjectKind.door.isMovable)
    }

    @Test("MockLayoutMapper assigns catalog IDs to mapped objects")
    func mockLayoutMapperCatalogIDs() throws {
        let beyondDTO = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")
        let beyond = MockLayoutMapper.layout(from: beyondDTO, legend: PreviewLayouts.sampleLegend)

        let tables = beyond.objects.filter { $0.kind == .table }
        #expect(!tables.isEmpty)
        #expect(tables.allSatisfy { $0.catalogID == "table-round-4" })

        let pillars = beyond.objects.filter { $0.kind == .pillar }
        #expect(!pillars.isEmpty)
        #expect(pillars.allSatisfy { $0.catalogID == "pillar-round" })

        let doorprizes = beyond.objects.filter { $0.label.uppercased().contains("DOORPRIZE") }
        #expect(!doorprizes.isEmpty)
        #expect(doorprizes.allSatisfy { $0.catalogID == "display-case" })

        let extensions = beyond.objects.filter { $0.label.uppercased().contains("EXT") }
        #expect(!extensions.isEmpty)
        #expect(extensions.allSatisfy { $0.catalogID == "stage-extension" })

        let annyeongDTO = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let annyeong = MockLayoutMapper.layout(from: annyeongDTO, legend: PreviewLayouts.sampleLegend)

        let clawMachines = annyeong.objects.filter { $0.label.uppercased().contains("CLAW") }
        #expect(!clawMachines.isEmpty)
        #expect(clawMachines.allSatisfy { $0.catalogID == "claw-machine" })
    }
}

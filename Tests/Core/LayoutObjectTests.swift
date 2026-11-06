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
            "kind": "block",
            "label": "T1",
            "placement": {
                "center": [5.0, 5.0],
                "sizeM": [1.0, 1.0],
                "rotationRadians": 0.0
            },
            "openSides": 0,
            "reviewState": "confirmed",
            "catalogID": "block",
            "heightM": 1.2
        }
        """

        let data = try #require(json.data(using: .utf8))
        let object = try JSONDecoder().decode(LayoutObject.self, from: data)

        #expect(object.catalogID == "block")
        #expect(object.heightM == 1.2)
    }
}

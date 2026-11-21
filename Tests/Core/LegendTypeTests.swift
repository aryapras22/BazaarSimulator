import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct LegendTypeTests {
    @Test("BoothType only includes fnb (Foods) and goods (Goods)")
    func boothTypeAllCasesAreFnbAndGoods() {
        #expect(BoothType.allCases == [.fnb, .goods])
        #expect(BoothType.allCases.map(\.displayName) == ["Foods", "Goods"])
    }

    @Test("Decoding a legend entry with legacy type others succeeds as unassigned")
    func legacyOthersDecodesToNil() throws {
        let id = UUID()
        let json = """
        {
            "id": "\(id.uuidString)",
            "name": "Misc",
            "color": { "red": 1.0, "green": 0.5, "blue": 0.0 },
            "type": "others"
        }
        """

        let decoded = try JSONDecoder().decode(LegendEntry.self, from: Data(json.utf8))

        #expect(decoded.id == id)
        #expect(decoded.name == "Misc")
        #expect(decoded.color == LegendColor(red: 1.0, green: 0.5, blue: 0.0))
        #expect(decoded.type == nil)
    }

    @Test("Decoding a legend entry with an unknown booth type fails")
    func unknownTypeFailsToDecode() {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Misc",
            "color": { "red": 1.0, "green": 0.0, "blue": 0.0 },
            "type": "services"
        }
        """

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LegendEntry.self, from: Data(json.utf8))
        }
    }

    @Test(
        "LegendEntry with fnb or goods round-trips with unchanged encoding",
        arguments: [(BoothType.fnb, "fnb"), (BoothType.goods, "goods")]
    )
    func fnbAndGoodsRoundTrip(type: BoothType, rawValue: String) throws {
        let entry = LegendEntry(name: "Category", color: Self.color, type: type)

        let data = try JSONEncoder().encode(entry)
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let decoded = try JSONDecoder().decode(LegendEntry.self, from: data)

        #expect(jsonObject?["type"] as? String == rawValue)
        #expect(decoded == entry)
    }

    @Test("LegendEntry with nil type round-trips as unassigned")
    func nilTypeRoundTrips() throws {
        let entry = LegendEntry(name: "Unassigned", color: Self.color, type: nil)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(LegendEntry.self, from: data)

        #expect(decoded == entry)
        #expect(decoded.type == nil)
    }

    private static let color = LegendColor(red: 1, green: 0, blue: 0)
}

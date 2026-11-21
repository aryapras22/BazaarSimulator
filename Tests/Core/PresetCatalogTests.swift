import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct PresetCatalogTests {
    @Test("The bundled presets load, use Explorer, and every bazaar type mix adds up to 100")
    func bundledPresets() {
        let catalog = PresetCatalog.bundled()
        #expect(catalog.visitorTypes.map(\.id) == ["socializer", "family", "explorer", "buyer"])
        #expect(catalog.visitorTypes.map(\.name) == ["Socializer", "Family Member", "Explorer", "Purpose Buyer"])
        #expect(catalog.bazaarTypes.count == 5)
        #expect(catalog.bazaarTypes.map(\.name) == [
            "Family & Kids", "Creative Exhibition", "Culinary", "Fashion", "Seasonal"
        ])
        for preset in catalog.bazaarTypes {
            let mix = catalog.mix(for: preset)
            #expect(mix.shares.reduce(0) { $0 + $1.percent } == 100, "\(preset.name)")
        }

        let expected: [String: [String: Int]] = [
            "Family & Kids": ["socializer": 20, "family": 50, "explorer": 15, "buyer": 15],
            "Creative Exhibition": ["socializer": 25, "family": 10, "explorer": 50, "buyer": 15],
            "Culinary": ["socializer": 30, "family": 20, "explorer": 20, "buyer": 30],
            "Fashion": ["socializer": 20, "family": 10, "explorer": 45, "buyer": 25],
            "Seasonal": ["socializer": 20, "family": 35, "explorer": 20, "buyer": 25]
        ]
        for preset in catalog.bazaarTypes {
            #expect(preset.mix == expected[preset.name], "\(preset.name)")
        }
        #expect(catalog.defaultParameters().totalVisitors == PresetCatalog.defaultTotalVisitors)
    }
}

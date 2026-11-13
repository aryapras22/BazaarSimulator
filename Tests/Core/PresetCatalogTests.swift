import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct PresetCatalogTests {
    @Test("The bundled presets load, and every bazaar type mix adds up to 100")
    func bundledPresets() {
        let catalog = PresetCatalog.bundled()
        #expect(catalog.visitorTypes.count == 4)
        #expect(!catalog.bazaarTypes.isEmpty)
        for preset in catalog.bazaarTypes {
            let mix = catalog.mix(for: preset)
            #expect(mix.shares.reduce(0) { $0 + $1.percent } == 100, "\(preset.name)")
        }
    }
}

import Foundation

/// The bundled visitor types and bazaar type presets.
struct PresetCatalog: Sendable {
    let visitorTypes: [VisitorType]
    let bazaarTypes: [BazaarTypePreset]

    /// Bundled data is part of the app, so a missing or broken file is a programmer error.
    static func bundled(in bundle: Bundle = .main) -> PresetCatalog {
        do {
            return PresetCatalog(
                visitorTypes: try MockDataStore.load(from: "visitor_types", in: bundle),
                bazaarTypes: try MockDataStore.load(from: "bazaar_types", in: bundle)
            )
        } catch {
            fatalError("Bundled presets are missing or invalid: \(error)")
        }
    }

    func bazaarType(id: String) -> BazaarTypePreset? {
        bazaarTypes.first { $0.id == id }
    }

    func mix(for preset: BazaarTypePreset) -> VisitorMix {
        VisitorMix(shares: visitorTypes.map {
            VisitorMix.Share(id: $0.id, percent: preset.mix[$0.id] ?? 0)
        })
    }

    /// What a project starts with: the first bazaar type, 10:00 to 21:00, no peak hours.
    func defaultParameters() -> EventParameters {
        let preset = bazaarTypes[0]
        return EventParameters(
            totalVisitors: preset.totalVisitors,
            eventHours: TimeRange(startMinute: 10 * 60, endMinute: 21 * 60),
            bazaarTypeID: preset.id,
            mix: mix(for: preset)
        )
    }
}

import Foundation

struct ProjectDraft: Sendable, Hashable, Codable {
    var name: String
    var legend: Legend
    var layouts: [Layout]
    var seedFingerprint: String?

    init(
        name: String,
        legend: Legend = Legend(),
        layouts: [Layout] = [],
        seedFingerprint: String? = nil
    ) {
        self.name = name
        self.legend = legend
        self.layouts = layouts
        self.seedFingerprint = seedFingerprint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedName = try container.decode(String.self, forKey: .name)
        let decodedLegend = try container.decode(Legend.self, forKey: .legend)
        let decodedLayouts = try container.decode([Layout].self, forKey: .layouts)
        let decodedSeedFingerprint = try container.decodeIfPresent(String.self, forKey: .seedFingerprint)
        self.name = decodedName
        self.legend = decodedLegend
        self.layouts = decodedLayouts.map { $0.resolvingBoothTypes(from: decodedLegend) }
        self.seedFingerprint = decodedSeedFingerprint
    }

    func resolvingBoothTypes() -> ProjectDraft {
        ProjectDraft(
            name: name,
            legend: legend,
            layouts: layouts.map { $0.resolvingBoothTypes(from: legend) },
            seedFingerprint: seedFingerprint
        )
    }
}

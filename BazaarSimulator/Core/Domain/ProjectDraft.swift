import Foundation

struct ProjectDraft: Sendable, Hashable, Codable {
    var name: String
    var legend: Legend
    var layouts: [Layout]

    init(name: String, legend: Legend = Legend(), layouts: [Layout] = []) {
        self.name = name
        self.legend = legend
        self.layouts = layouts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedName = try container.decode(String.self, forKey: .name)
        let decodedLegend = try container.decode(Legend.self, forKey: .legend)
        let decodedLayouts = try container.decode([Layout].self, forKey: .layouts)
        self.name = decodedName
        self.legend = decodedLegend
        self.layouts = decodedLayouts.map { $0.resolvingBoothTypes(from: decodedLegend) }
    }

    func resolvingBoothTypes() -> ProjectDraft {
        ProjectDraft(
            name: name,
            legend: legend,
            layouts: layouts.map { $0.resolvingBoothTypes(from: legend) }
        )
    }
}

import Foundation

struct ProjectDraft: Sendable, Hashable, Codable {
    var name: String
    var legend: Legend
    var layouts: [ExtractedLayout]

    init(name: String, legend: Legend = Legend(), layouts: [ExtractedLayout] = []) {
        self.name = name
        self.legend = legend
        self.layouts = layouts
    }
}

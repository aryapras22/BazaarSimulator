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
}

import Foundation

struct LegendColor: Sendable, Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
}

struct LegendEntry: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: LegendColor

    init(id: UUID = UUID(), name: String, color: LegendColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

struct Legend: Sendable, Hashable, Codable {
    var entries: [LegendEntry]

    init(entries: [LegendEntry] = []) {
        self.entries = entries
    }
}

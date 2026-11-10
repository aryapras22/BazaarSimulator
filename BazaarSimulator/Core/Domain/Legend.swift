import Foundation

struct LegendColor: Sendable, Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
}

enum BoothType: String, Sendable, Hashable, Codable, CaseIterable {
    case fnb
    case fashion
    case lifestyleAndHobbies

    var displayName: String {
        switch self {
        case .fnb: "FNB"
        case .fashion: "Fashion"
        case .lifestyleAndHobbies: "Lifestyle & Hobbies"
        }
    }
}

struct LegendEntry: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: LegendColor
    /// Picked by the user after the legend is read. Nil until they choose one.
    var type: BoothType?

    init(id: UUID = UUID(), name: String, color: LegendColor, type: BoothType? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.type = type
    }
}

struct Legend: Sendable, Hashable, Codable {
    var entries: [LegendEntry]

    init(entries: [LegendEntry] = []) {
        self.entries = entries
    }
}

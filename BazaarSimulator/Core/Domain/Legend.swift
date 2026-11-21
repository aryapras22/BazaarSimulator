import Foundation

struct LegendColor: Sendable, Hashable, Codable {
    let red: Double
    let green: Double
    let blue: Double
}

enum BoothType: String, Sendable, Hashable, Codable, CaseIterable {
    case fnb
    case goods

    var displayName: String {
        switch self {
        case .fnb: "Foods"
        case .goods: "Goods"
        }
    }
}

struct LegendEntry: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    var name: String
    var color: LegendColor
    /// Picked by the user after the legend is read. Nil until they choose one.
    var type: BoothType?

    private enum CodingKeys: String, CodingKey {
        case id, name, color, type
    }

    init(id: UUID = UUID(), name: String, color: LegendColor, type: BoothType? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.type = type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(LegendColor.self, forKey: .color)
        if let rawType = try container.decodeIfPresent(String.self, forKey: .type), rawType != "others" {
            type = try container.decode(BoothType.self, forKey: .type)
        } else {
            type = nil
        }
    }
}

struct Legend: Sendable, Hashable, Codable {
    var entries: [LegendEntry]

    init(entries: [LegendEntry] = []) {
        self.entries = entries
    }
}

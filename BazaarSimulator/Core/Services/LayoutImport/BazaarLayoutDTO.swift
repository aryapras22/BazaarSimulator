import Foundation

struct BazaarLayoutDTO: Decodable, Sendable, Equatable {
    let meta: BazaarMetaDTO
    let booths: [BazaarBoothDTO]
    let doors: [BazaarDoorDTO]
    let tables: [BazaarTableDTO]
}

struct BazaarWorldDTO: Decodable, Sendable, Equatable {
    let width: Double
    let height: Double

    enum CodingKeys: String, CodingKey {
        case width = "w"
        case height = "h"
    }
}

struct BazaarMetaDTO: Decodable, Sendable, Equatable {
    let name: String
    let sheet: String
    let world: BazaarWorldDTO
}

struct BazaarBoothDTO: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let type: String
    let centerX: Double
    let centerY: Double
    let width: Double
    let height: Double

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case centerX = "cx"
        case centerY = "cy"
        case width = "w"
        case height = "h"
    }
}

struct BazaarDoorDTO: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let role: String
}

struct BazaarTableDTO: Decodable, Sendable, Equatable {
    let centerX: Double
    let centerY: Double

    enum CodingKeys: String, CodingKey {
        case centerX = "cx"
        case centerY = "cy"
    }
}

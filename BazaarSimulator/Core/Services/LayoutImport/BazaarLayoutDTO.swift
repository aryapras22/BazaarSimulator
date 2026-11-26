import Foundation

struct BazaarLayoutDTO: Decodable, Sendable, Equatable {
    let meta: BazaarMetaDTO
    let hall: [[Double]]
    let lobby: [[Double]]
    let wall: BazaarRectDTO?
    let doors: [BazaarDoorDTO]
    let outerDoors: [BazaarOuterDoorDTO]
    let gates: [BazaarMarkerDTO]
    let exitPt: BazaarMarkerDTO
    let booths: [BazaarBoothDTO]
    let tables: [BazaarTableDTO]
    let stage: BazaarStageDTO?
    let kids: BazaarRectDTO?
    let kidsSeats: Bool?
    let kidsLabel: String?
    let columns: [BazaarColumnDTO]
    let pilasters: [BazaarPilasterDTO]
    let fixtures: [BazaarFixtureDTO]
    let closed: [BazaarRectDTO]
    let foyer: BazaarZoneDTO?
    let corridor: BazaarZoneDTO?
    // `pantia`, `arrows`, and `lobbyBlock` are empty or all zero in both bundled files and are not decoded.
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
    let note: String?
}

/// The box before any turn. A restricted area may add `shape: "round"` for the oval filling the box,
/// and `rot` in degrees to turn it about the box centre.
struct BazaarRectDTO: Decodable, Sendable, Equatable {
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    var shape: String?
    var rotationDegrees: Double?

    enum CodingKeys: String, CodingKey {
        case minX = "x0"
        case maxX = "x1"
        case minY = "y0"
        case maxY = "y1"
        case shape
        case rotationDegrees = "rot"
    }
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
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case minX = "x0"
        case maxX = "x1"
        case minY = "y0"
        case maxY = "y1"
    }
}

struct BazaarOuterDoorDTO: Decodable, Sendable, Equatable {
    let posX: Double
    let minY: Double
    let maxY: Double

    enum CodingKeys: String, CodingKey {
        case posX = "x"
        case minY = "y0"
        case maxY = "y1"
    }
}

struct BazaarMarkerDTO: Decodable, Identifiable, Sendable, Equatable {
    let id: String
    let posX: Double
    let posY: Double

    enum CodingKeys: String, CodingKey {
        case id
        case posX = "sx"
        case posY = "sy"
    }
}

struct BazaarTableDTO: Decodable, Sendable, Equatable {
    let centerX: Double
    let centerY: Double
    let width: Double
    let height: Double

    enum CodingKeys: String, CodingKey {
        case centerX = "cx"
        case centerY = "cy"
        case width = "w"
        case height = "h"
    }
}

struct BazaarStageDTO: Decodable, Sendable, Equatable {
    let face: String
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double

    enum CodingKeys: String, CodingKey {
        case face
        case minX = "x0"
        case maxX = "x1"
        case minY = "y0"
        case maxY = "y1"
    }
}

struct BazaarColumnDTO: Decodable, Sendable, Equatable {
    let posX: Double
    let posY: Double
    let diameter: Double

    enum CodingKeys: String, CodingKey {
        case posX = "x"
        case posY = "y"
        case diameter = "d"
    }
}

/// A wall may add `rot` in degrees: the box is then the wall before the turn, length along x, turned about its centre.
struct BazaarPilasterDTO: Decodable, Sendable, Equatable {
    let kind: String
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    var rotationDegrees: Double?

    enum CodingKeys: String, CodingKey {
        case kind
        case minX = "x0"
        case maxX = "x1"
        case minY = "y0"
        case maxY = "y1"
        case rotationDegrees = "rot"
    }
}

/// Takes the same optional `shape` and `rot` as a restricted area.
struct BazaarFixtureDTO: Decodable, Sendable, Equatable {
    let label: String
    let kind: String
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    var shape: String?
    var rotationDegrees: Double?

    enum CodingKeys: String, CodingKey {
        case label
        case kind
        case minX = "x0"
        case maxX = "x1"
        case minY = "y0"
        case maxY = "y1"
        case shape
        case rotationDegrees = "rot"
    }
}

struct BazaarZoneDTO: Decodable, Sendable, Equatable {
    let minX: Double
    let maxX: Double
    let label: [Double]

    enum CodingKeys: String, CodingKey {
        case minX = "x0"
        case maxX = "x1"
        case label
    }
}

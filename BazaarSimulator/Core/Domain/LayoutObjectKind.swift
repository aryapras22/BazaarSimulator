import Foundation

enum LayoutObjectKind: String, Codable, CaseIterable, Hashable, Sendable {
    case booth
    case table
    case door
    case wall
    case rail
    case block
    case pillar
    case fixture
    case stage
    case audienceArea
    case closedArea
    case floor

    var displayName: String {
        switch self {
        case .booth: return "Booth"
        case .table: return "Table"
        case .door: return "Door"
        case .wall: return "Wall"
        case .rail: return "Rail"
        case .block: return "Block"
        case .pillar: return "Pillar"
        case .fixture: return "Fixture"
        case .stage: return "Stage"
        case .audienceArea: return "Audience area"
        case .closedArea: return "Blocked area"
        case .floor: return "Floor"
        }
    }

    var layer: EditorLayer {
        switch self {
        case .wall, .rail, .block, .pillar, .door, .closedArea, .stage, .audienceArea, .floor:
            return .structure
        case .booth, .table, .fixture:
            return .booths
        }
    }

    var isMovable: Bool {
        true
    }

    var isResizable: Bool {
        true
    }

    var isRotatable: Bool {
        switch self {
        case .door, .pillar: return false
        default: return true
        }
    }

    var hasCategory: Bool {
        self == .booth
    }

    var hasOpenSides: Bool {
        self == .booth || self == .stage
    }

    var allowsMultipleOpenSides: Bool {
        self == .booth
    }

    var blocksWalking: Bool {
        switch self {
        case .door, .audienceArea, .floor: return false
        default: return true
        }
    }

    var canBeAdded: Bool {
        switch self {
        case .booth, .table, .rail, .fixture, .closedArea, .wall, .block, .pillar, .stage, .door, .floor:
            return true
        default:
            return false
        }
    }

    var minimumDimensionM: Double {
        switch self {
        case .booth, .table, .fixture, .stage, .audienceArea, .closedArea, .floor: return 0.5
        case .door: return 0.8
        case .wall, .rail, .block, .pillar: return 0.1
        }
    }

    var isSelectable: Bool {
        isMovable || isResizable
    }

    var hasResizeHandles: Bool {
        self == .closedArea || self == .floor
    }

    var isStructural: Bool {
        switch self {
        case .wall, .pillar, .closedArea, .floor: return true
        default: return false
        }
    }
}

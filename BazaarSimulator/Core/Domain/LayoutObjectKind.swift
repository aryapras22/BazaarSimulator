import Foundation

enum LayoutObjectTab: String, Codable, CaseIterable, Hashable, Sendable {
    case floorPlan
    case flow
}

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
        case .closedArea: return "Closed area"
        }
    }

    var tab: LayoutObjectTab {
        switch self {
        case .door: return .flow
        default: return .floorPlan
        }
    }

    var isMovable: Bool {
        switch self {
        case .door, .closedArea: return false
        default: return true
        }
    }

    var isResizable: Bool {
        switch self {
        case .closedArea: return false
        default: return true
        }
    }

    var isRotatable: Bool {
        switch self {
        case .door, .pillar, .closedArea: return false
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
        case .door, .audienceArea: return false
        default: return true
        }
    }

    var canBeAdded: Bool {
        switch self {
        case .booth, .table, .rail, .fixture: return true
        default: return false
        }
    }

    var minimumDimensionM: Double {
        switch self {
        case .booth, .table, .fixture, .stage, .audienceArea: return 0.5
        case .door: return 0.8
        case .wall, .rail, .block, .pillar, .closedArea: return 0.1
        }
    }

    var isSelectable: Bool {
        isMovable || isResizable
    }
}

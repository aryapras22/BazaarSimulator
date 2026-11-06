import Foundation

enum LayoutObjectKind: String, Codable, CaseIterable, Hashable, Sendable {
    case booth
    case door
    case wall
    case block
    case closedArea
    case floor

    var displayName: String {
        switch self {
        case .booth: return "Booth"
        case .door: return "Door"
        case .wall: return "Wall"
        case .block: return "Block"
        case .closedArea: return "Blocked area"
        case .floor: return "Floor"
        }
    }

    var layer: EditorLayer {
        switch self {
        case .wall, .block, .door, .closedArea, .floor:
            return .structure
        case .booth:
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
        self != .door
    }

    var hasCategory: Bool {
        self == .booth
    }

    var hasOpenSides: Bool {
        self == .booth
    }

    var allowsMultipleOpenSides: Bool {
        self == .booth
    }

    var blocksWalking: Bool {
        switch self {
        case .door, .floor: return false
        default: return true
        }
    }

    var minimumDimensionM: Double {
        switch self {
        case .booth, .closedArea, .floor: return 0.5
        case .door: return 0.8
        case .wall, .block: return 0.1
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
        case .wall, .block, .closedArea, .floor: return true
        default: return false
        }
    }
}

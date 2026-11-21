import Foundation

enum LayoutObjectKind: String, Codable, CaseIterable, Hashable, Sendable {
    case booth
    case door
    case wall
    case block
    case closedArea
    case table
    case seating
    case entertainment

    var displayName: String {
        switch self {
        case .booth: return "Booth"
        case .door: return "Door"
        case .wall: return "Wall"
        case .block: return "Object"
        case .closedArea: return "Restricted area"
        case .table: return "Table"
        case .seating: return "Seating"
        case .entertainment: return "Entertainment"
        }
    }

    var layer: EditorLayer {
        switch self {
        case .wall, .block, .door, .closedArea:
            return .structure
        case .booth, .table, .seating, .entertainment:
            return .booths
        }
    }

    var isMovable: Bool {
        true
    }

    /// Columns, totems and voids can be round; booths, walls and doors keep square corners.
    var canBeRound: Bool {
        self == .block || self == .closedArea
    }

    /// A table takes its size from its standard model.
    var isResizable: Bool {
        self != .table
    }

    var isRotatable: Bool {
        self != .door
    }

    /// Tables and seating stand at any eighth of a turn, as plans draw them. Everything else turns by quarters.
    var rotationStepDegrees: Int {
        self == .table || self == .seating ? 45 : 90
    }

    var hasCategory: Bool {
        self == .booth
    }

    var hasOpenSides: Bool {
        self == .booth || self == .entertainment
    }

    var allowsMultipleOpenSides: Bool {
        hasOpenSides
    }

    var blocksWalking: Bool {
        switch self {
        case .door, .seating: return false
        default: return true
        }
    }

    var minimumDimensionM: Double {
        switch self {
        case .booth, .closedArea, .table, .seating, .entertainment: return 0.5
        case .door: return 0.8
        case .wall, .block: return 0.1
        }
    }

    var isSelectable: Bool {
        isMovable || isResizable
    }

    /// Walls resize through their end nodes and doors are fitted to their wall, so neither gets box handles.
    var hasResizeHandles: Bool {
        self == .closedArea || self == .booth || self == .block || self == .seating || self == .entertainment
    }

    var hasAttractiveness: Bool {
        self == .booth || self == .entertainment
    }

    /// Entertainment starts at the top of the scale. The user can lower it like a booth's.
    var defaultAttractiveness: Double {
        self == .entertainment ? 5 : 1
    }

    var isStructural: Bool {
        switch self {
        case .wall, .block, .closedArea: return true
        default: return false
        }
    }
}

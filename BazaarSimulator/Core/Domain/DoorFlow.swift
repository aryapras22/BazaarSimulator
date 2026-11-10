import Foundation

enum DoorDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case entrance
    case exit
    case both
    case disabled

    var displayName: String {
        switch self {
        case .entrance: return "Entrance"
        case .exit: return "Exit"
        case .both: return "Both"
        case .disabled: return "Disable"
        }
    }

    var allowsEntry: Bool {
        self == .entrance || self == .both
    }

    var allowsExit: Bool {
        self == .exit || self == .both
    }
}

enum DoorConnection: String, Codable, Hashable, Sendable {
    case hallToLobby
    case hallToOutside
    case lobbyToOutside
}

struct DoorFlow: Codable, Hashable, Sendable {
    var direction: DoorDirection
    var connection: DoorConnection

    init(direction: DoorDirection, connection: DoorConnection = .hallToLobby) {
        self.direction = direction
        self.connection = connection
    }
}

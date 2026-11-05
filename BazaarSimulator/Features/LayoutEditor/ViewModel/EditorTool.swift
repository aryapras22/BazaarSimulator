import Foundation

enum EditorTool: Hashable, Sendable {
    case select
    case blockedArea
    case floor(itemID: String)
    case place(LibraryRowDisplay.Source)
    case drawWall(itemID: String)
    case room(itemID: String)
    case placeDoor(itemID: String)

    static let primaryTools: [EditorTool] = [.select, .blockedArea]

    var title: String {
        switch self {
        case .select: return "Select"
        case .blockedArea: return "Blocked Area"
        case .floor: return "Floor"
        case .place: return "Place"
        case .drawWall: return "Draw Wall"
        case .room: return "Room"
        case .placeDoor: return "Place Door"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .blockedArea: return "square.dashed"
        case .floor: return "square.fill"
        case .place: return "plus.square"
        case .drawWall: return "line.diagonal"
        case .room: return "rectangle"
        case .placeDoor: return "door.left.hand.open"
        }
    }
}

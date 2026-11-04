import Foundation

enum EditorTool: Hashable, Sendable {
    case select
    case blockedArea
    case place(LibraryRowDisplay.Source)
    case drawWall(itemID: String)
    case placeDoor(itemID: String)

    static let primaryTools: [EditorTool] = [.select, .blockedArea]

    var title: String {
        switch self {
        case .select: return "Select"
        case .blockedArea: return "Blocked Area"
        case .place: return "Place"
        case .drawWall: return "Draw Wall"
        case .placeDoor: return "Place Door"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .blockedArea: return "square.dashed"
        case .place: return "plus.square"
        case .drawWall: return "line.diagonal"
        case .placeDoor: return "door.left.hand.open"
        }
    }
}

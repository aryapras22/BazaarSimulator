import Foundation

enum EditorTool: Hashable, Sendable {
    case select
    case blockedArea
    case row(sizeM: SIMD2<Double> = SIMD2(2.5, 2.5))
    case fill(sizeM: SIMD2<Double> = SIMD2(2.5, 2.5), aisleWidthM: Double = 2.0)
    case place(LibraryRowDisplay.Source)
    case drawWall(itemID: String)
    case room(itemID: String)
    case placeDoor(itemID: String)

    static let primaryTools: [EditorTool] = [.select, .blockedArea]

    var title: String {
        switch self {
        case .select: return "Select"
        case .blockedArea: return "Blocked Area"
        case .row: return "Row"
        case .fill: return "Fill"
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
        case .row: return "rectangle.split.3x1"
        case .fill: return "square.grid.3x3"
        case .place: return "plus.square"
        case .drawWall: return "line.diagonal"
        case .room: return "rectangle"
        case .placeDoor: return "door.left.hand.open"
        }
    }
}

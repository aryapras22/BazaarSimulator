import Foundation

enum EditorTool: String, CaseIterable, Hashable, Sendable {
    case select
    case blockedArea

    var title: String {
        switch self {
        case .select: return "Select"
        case .blockedArea: return "Blocked Area"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .blockedArea: return "square.dashed"
        }
    }
}

import Foundation

enum EditorLayer: String, Codable, CaseIterable, Hashable, Sendable {
    case structure
    case booths

    var title: String {
        switch self {
        case .structure: return "Structure"
        case .booths: return "Booths"
        }
    }
}

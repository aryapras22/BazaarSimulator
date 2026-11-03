import Foundation

enum EditorTab: String, CaseIterable, Hashable, Sendable {
    case floorPlan
    case flow

    var title: String {
        switch self {
        case .floorPlan: return "Floor Plan"
        case .flow: return "Flow"
        }
    }

    var objectTab: LayoutObjectTab {
        switch self {
        case .floorPlan: return .floorPlan
        case .flow: return .flow
        }
    }
}

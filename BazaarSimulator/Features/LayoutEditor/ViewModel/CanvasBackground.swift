import Foundation

enum CanvasBackground: String, CaseIterable, Identifiable, Sendable {
    case standard
    case grey
    case white

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: return "Default"
        case .grey: return "Grey"
        case .white: return "White"
        }
    }
}

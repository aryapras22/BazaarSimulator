import Foundation

enum CanvasBackground: String, CaseIterable, Identifiable, Sendable {
    case standard
    case autoCAD
    case white

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: return "Default"
        case .autoCAD: return "AutoCAD"
        case .white: return "White"
        }
    }
}

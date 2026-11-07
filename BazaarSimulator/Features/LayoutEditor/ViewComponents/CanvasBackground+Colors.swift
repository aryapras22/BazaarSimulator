import SwiftUI

extension CanvasBackground {
    var fill: Color {
        switch self {
        case .standard: return Palette.background
        case .autoCAD: return Palette.canvasBackgroundAutoCAD
        case .white: return Palette.canvasBackgroundWhite
        }
    }

    var gridLine: Color {
        switch self {
        case .standard: return Palette.canvasGridLine
        case .autoCAD: return Palette.canvasGridLineAutoCAD
        case .white: return Palette.canvasGridLineWhite
        }
    }
}

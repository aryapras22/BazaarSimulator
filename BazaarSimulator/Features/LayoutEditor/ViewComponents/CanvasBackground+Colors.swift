import SwiftUI

extension CanvasBackground {
    var fill: Color {
        switch self {
        case .standard: return Palette.background
        case .grey: return Palette.canvasBackgroundGrey
        case .white: return Palette.canvasBackgroundWhite
        }
    }

    var gridLine: Color {
        switch self {
        case .standard: return Palette.canvasGridLine
        case .grey: return Palette.canvasGridLineGrey
        case .white: return Palette.canvasGridLineWhite
        }
    }
}

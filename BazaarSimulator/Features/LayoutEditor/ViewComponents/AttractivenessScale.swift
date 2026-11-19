import SwiftUI

enum AttractivenessDisplay: Sendable {
    case hidden
    case dot
    case heat
}

enum AttractivenessScale {
    static let defaultValue: Double = 1
    static let minimumOpacity: Double = 0.25

    static func fraction(of value: Double) -> Double {
        let range = AttractivenessField.range
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    static func opacity(for value: Double) -> Double {
        minimumOpacity + (1 - minimumOpacity) * fraction(of: value)
    }

    static func color(for value: Double) -> Color {
        Palette.attractiveness.opacity(opacity(for: value))
    }

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [Palette.attractiveness.opacity(minimumOpacity), Palette.attractiveness],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

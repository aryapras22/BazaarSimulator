import SwiftUI

enum AttractivenessDisplay: Sendable {
    case hidden
    case dot
    case heat
}

enum AttractivenessScale {
    static let defaultValue: Double = 1

    static func fraction(of value: Double) -> Double {
        let range = AttractivenessField.range
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    static func step(for value: Double) -> Int {
        let range = AttractivenessField.range
        let clamped = min(max(value.rounded(), range.lowerBound), range.upperBound)
        return Int(clamped - range.lowerBound)
    }

    static func color(for value: Double) -> Color {
        Palette.attractivenessSteps[step(for: value)]
    }

    static func isDarkStep(for value: Double) -> Bool {
        step(for: value) >= 3
    }

    static var gradient: LinearGradient {
        LinearGradient(
            colors: Palette.attractivenessSteps,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

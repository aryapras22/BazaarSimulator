import SwiftUI

enum AttractivenessScale {
    static func fraction(of value: Double) -> Double {
        let range = AttractivenessField.range
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    static func color(for value: Double) -> Color {
        let fraction = fraction(of: value)
        if fraction < 0.5 {
            return Palette.attractivenessLow.mix(with: Palette.attractivenessMid, by: fraction * 2)
        }
        return Palette.attractivenessMid.mix(with: Palette.attractivenessHigh, by: (fraction - 0.5) * 2)
    }

    static var gradient: LinearGradient {
        LinearGradient(
            colors: [Palette.attractivenessLow, Palette.attractivenessMid, Palette.attractivenessHigh],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

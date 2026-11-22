import SwiftUI

/// Green through yellow and orange to red for crowd density, and a distinct green-to-warm-red scale for walked paths.
enum HeatScale {
    static let colors: [Color] = [.heatLow, .heatMedium, .heatOrange, .heatHigh]

    static let footfallColors: [Color] = [
        Color(.sRGB, red: 0.16, green: 0.74, blue: 0.36, opacity: 1),
        Color(.sRGB, red: 0.62, green: 0.78, blue: 0.28, opacity: 1),
        Color(.sRGB, red: 0.86, green: 0.44, blue: 0.28, opacity: 1)
    ]

    /// 0 up to the "restricted" grade, then rising through the stuck level to jammed.
    static func level(forDensity density: Double) -> Double {
        let start = SeverityGrade.c.lowerDensity, heavy = SeverityGrade.e.lowerDensity, jammed = SeverityGrade.f.lowerDensity
        if density <= start { return 0 }
        if density <= heavy { return (density - start) / (heavy - start) * 0.5 }
        return min(0.5 + (density - heavy) / (jammed - heavy) * 0.5, 1)
    }

    static func color(forLevel level: Double) -> Color {
        let position = min(max(level, 0), 1) * Double(colors.count - 1)
        let index = min(Int(position), colors.count - 2)
        return colors[index].mix(with: colors[index + 1], by: position - Double(index))
    }

    static func footfallColor(forLevel level: Double) -> Color {
        let position = min(max(level, 0), 1) * Double(footfallColors.count - 1)
        let index = min(Int(position), footfallColors.count - 2)
        return footfallColors[index].mix(with: footfallColors[index + 1], by: position - Double(index))
    }

    static func footfallAlpha(forLevel level: Double) -> Double {
        let clamped = min(max(level, 0), 1)
        guard clamped > 0 else { return 0 }
        return 0.10 + 0.76 * pow(clamped, 0.85)
    }
}

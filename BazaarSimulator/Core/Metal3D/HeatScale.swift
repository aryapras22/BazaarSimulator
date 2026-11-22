import SwiftUI

/// Green through yellow and orange to red for crowd density, and a distinct green-to-warm-red scale for walked paths.
enum HeatScale {
    static let colors: [Color] = [.heatLow, .heatMedium, .heatOrange, .heatHigh]

    static let footfallColors: [Color] = [
        Color(.sRGB, red: 0.14, green: 0.74, blue: 0.34, opacity: 1),
        Color(.sRGB, red: 0.56, green: 0.82, blue: 0.22, opacity: 1),
        Color(.sRGB, red: 0.94, green: 0.38, blue: 0.20, opacity: 1)
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
        return 0.12 + 0.80 * pow(clamped, 0.85)
    }
}

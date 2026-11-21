import SwiftUI

/// Green through yellow and orange to red, for crowd density and walked paths.
enum HeatScale {
    static let colors: [Color] = [.heatLow, .heatMedium, .heatOrange, .heatHigh]

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
}

import AppKit
import simd
import SwiftUI

/// One tenant category shown in the simulation legend and matched to booth fills in 2D and 3D.
struct TenantLegendItem: Identifiable, Equatable {
    let id: String
    let name: String
    let rgba: SIMD4<Float>

    var color: Color {
        Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z), opacity: Double(rgba.w))
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: CGFloat(rgba.w)
        )
    }
}

/// Slightly differentiated, cohesive booth colors shared across 2D SpriteKit, 3D Metal, and the info panel legend.
enum TenantColors {
    static let foodRGBA = SIMD4<Float>(0.76, 0.41, 0.36, 1)
    static let goodsPalette: [SIMD4<Float>] = [
        SIMD4<Float>(0.29, 0.50, 0.74, 1),
        SIMD4<Float>(0.27, 0.62, 0.58, 1),
        SIMD4<Float>(0.73, 0.60, 0.34, 1),
        SIMD4<Float>(0.53, 0.43, 0.67, 1),
        SIMD4<Float>(0.43, 0.60, 0.42, 1),
        SIMD4<Float>(0.36, 0.59, 0.70, 1)
    ]

    private static let foodKeywords = ["food", "f&b", "fnb"]

    static func isFood(_ entry: LegendEntry) -> Bool {
        if entry.type == .fnb { return true }
        let lowered = entry.name.lowercased()
        return foodKeywords.contains { lowered.contains($0) }
    }

    static func isFood(_ object: LayoutObject, legend: Legend = Legend()) -> Bool {
        if let categoryID = object.categoryID,
           let entry = legend.entries.first(where: { $0.id == categoryID }) {
            return isFood(entry)
        }
        if object.boothType == .fnb { return true }
        let label = object.label.lowercased()
        return foodKeywords.contains { label.contains($0) } || label.hasPrefix("f")
    }

    /// Legend items shown at the bottom of the simulation details panel.
    static func legendItems(for layout: Layout?, legend: Legend) -> [TenantLegendItem] {
        if !legend.entries.isEmpty {
            var nonFoodIndex = 0
            return legend.entries.map { entry in
                let rgba: SIMD4<Float>
                if isFood(entry) {
                    rgba = foodRGBA
                } else {
                    rgba = goodsPalette[nonFoodIndex % goodsPalette.count]
                    nonFoodIndex += 1
                }
                return TenantLegendItem(id: entry.id.uuidString, name: entry.name, rgba: rgba)
            }
        }

        let booths = layout?.objects.filter { $0.kind == .booth } ?? []
        guard !booths.isEmpty else { return [] }
        let hasFood = booths.contains { isFood($0) }
        let hasGoods = booths.contains { !isFood($0) }
        var items: [TenantLegendItem] = []
        if hasFood { items.append(TenantLegendItem(id: "fnb", name: "F&B", rgba: foodRGBA)) }
        if hasGoods { items.append(TenantLegendItem(id: "goods", name: "Goods", rgba: goodsPalette[0])) }
        return items
    }

    /// Resolved RGBA color for one booth object.
    static func boothRGBA(for object: LayoutObject, legend: Legend = Legend()) -> SIMD4<Float> {
        if let categoryID = object.categoryID {
            let items = legendItems(for: nil, legend: legend)
            if let match = items.first(where: { $0.id == categoryID.uuidString }) {
                return match.rgba
            }
        }
        return isFood(object, legend: legend) ? foodRGBA : goodsPalette[0]
    }

    static func boothNSColor(for object: LayoutObject, legend: Legend = Legend()) -> NSColor {
        let rgba = boothRGBA(for: object, legend: legend)
        return NSColor(
            calibratedRed: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: CGFloat(rgba.w)
        )
    }
}

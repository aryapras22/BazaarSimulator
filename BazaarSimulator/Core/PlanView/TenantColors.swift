import AppKit
import simd
import SwiftUI

/// One tenant category shown in the simulation legend and matched to booth and attraction fills in 2D and 3D.
struct TenantLegendItem: Identifiable, Equatable {
    let id: String
    let name: String
    let rgba: SIMD4<Float>

    var color: Color {
        TenantColors.color(for: rgba)
    }

    var nsColor: NSColor {
        TenantColors.nsColor(for: rgba)
    }
}

/// Cohesive fixed category colors shared across 2D SpriteKit, 3D Metal, layout preview, and the simulation legend.
enum TenantColors {
    static let hallFloorRGBA = VenueGeometry.hallFloorColor
    static let lobbyFloorRGBA = VenueGeometry.lobbyFloorColor
    static let outlineRGBA = VenueGeometry.frameColor
    static let hallFloorColor = color(for: hallFloorRGBA)
    static let lobbyFloorColor = color(for: lobbyFloorRGBA)
    static let outlineColor = color(for: outlineRGBA)

    static let unassignedRGBA = SIMD4<Float>(0.56, 0.59, 0.65, 1)
    static let foodRGBA = SIMD4<Float>(0.76, 0.41, 0.36, 1)
    static let goodsPalette: [SIMD4<Float>] = [
        SIMD4<Float>(0.29, 0.50, 0.74, 1),
        SIMD4<Float>(0.27, 0.62, 0.58, 1),
        SIMD4<Float>(0.73, 0.60, 0.34, 1),
        SIMD4<Float>(0.53, 0.43, 0.67, 1),
        SIMD4<Float>(0.43, 0.60, 0.42, 1),
        SIMD4<Float>(0.36, 0.59, 0.70, 1)
    ]

    static func isFood(_ object: LayoutObject, legend: Legend = Legend()) -> Bool {
        object.boothType == .fnb
    }

    /// Legend items shown at the bottom of the simulation details panel, in `CategoryPicker` order.
    static func legendItems(for layout: Layout?, legend: Legend = Legend()) -> [TenantLegendItem] {
        guard let objects = layout?.objects else { return [] }

        let booths = objects.filter { $0.kind == .booth }
        var items: [TenantLegendItem] = []
        if booths.contains(where: { $0.boothType == nil }) {
            items.append(TenantLegendItem(id: "booth-unassigned", name: "Unassigned", rgba: unassignedRGBA))
        }
        if booths.contains(where: { $0.boothType == .fnb }) {
            items.append(TenantLegendItem(id: "booth-fnb", name: "Foods", rgba: foodRGBA))
        }
        if booths.contains(where: { $0.boothType == .goods }) {
            items.append(TenantLegendItem(id: "booth-goods", name: "Goods", rgba: goodsPalette[0]))
        }

        let presentEntertainment = Set(
            objects
                .filter { $0.kind == .entertainment }
                .map { EntertainmentType.resolve(catalogID: $0.catalogID, label: $0.label) }
        )
        for type in EntertainmentType.allCases where presentEntertainment.contains(type) {
            items.append(
                TenantLegendItem(id: type.catalogID, name: type.displayName, rgba: entertainmentRGBA(for: type))
            )
        }
        return items
    }

    /// Resolved RGBA color for one booth object.
    static func boothRGBA(for object: LayoutObject, legend: Legend = Legend()) -> SIMD4<Float> {
        switch object.boothType {
        case nil: unassignedRGBA
        case .fnb: foodRGBA
        case .goods: goodsPalette[0]
        }
    }

    static func boothNSColor(for object: LayoutObject, legend: Legend = Legend()) -> NSColor {
        nsColor(for: boothRGBA(for: object, legend: legend))
    }

    static func entertainmentRGBA(for type: EntertainmentType) -> SIMD4<Float> {
        switch type {
        case .stage: SIMD4<Float>(0.85, 0.56, 0.26, 1)
        case .photobooth: SIMD4<Float>(0.60, 0.44, 0.74, 1)
        case .informationDesk: SIMD4<Float>(0.27, 0.64, 0.58, 1)
        case .other: SIMD4<Float>(0.73, 0.65, 0.35, 1)
        case .disabled: SIMD4<Float>(0.40, 0.43, 0.48, 1)
        }
    }

    static func entertainmentRGBA(for object: LayoutObject) -> SIMD4<Float> {
        entertainmentRGBA(for: EntertainmentType.resolve(catalogID: object.catalogID, label: object.label))
    }

    static func entertainmentNSColor(for type: EntertainmentType) -> NSColor {
        nsColor(for: entertainmentRGBA(for: type))
    }

    static func entertainmentNSColor(for object: LayoutObject) -> NSColor {
        nsColor(for: entertainmentRGBA(for: object))
    }

    static func objectRGBA(for object: LayoutObject, legend: Legend = Legend()) -> SIMD4<Float> {
        switch object.kind {
        case .booth: boothRGBA(for: object, legend: legend)
        case .table: VenueGeometry.yellowColor
        case .seating: VenueGeometry.paleBlueColor
        case .entertainment: entertainmentRGBA(for: object)
        case .door: VenueGeometry.doorColor(for: object)
        case .wall: VenueGeometry.whiteColor
        case .block where object.isColumn: VenueGeometry.cobaltColor
        case .block: VenueGeometry.blockColor
        case .closedArea: VenueGeometry.paleBlueColor
        }
    }

    static func objectColor(for object: LayoutObject, legend: Legend = Legend()) -> Color {
        color(for: objectRGBA(for: object, legend: legend))
    }

    static func objectNSColor(for object: LayoutObject, legend: Legend = Legend()) -> NSColor {
        nsColor(for: objectRGBA(for: object, legend: legend))
    }

    static func color(for rgba: SIMD4<Float>) -> Color {
        Color(.sRGB, red: Double(rgba.x), green: Double(rgba.y), blue: Double(rgba.z), opacity: Double(rgba.w))
    }

    static func nsColor(for rgba: SIMD4<Float>) -> NSColor {
        NSColor(
            srgbRed: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: CGFloat(rgba.w)
        )
    }
}

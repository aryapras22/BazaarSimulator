import SwiftUI

enum LayoutID: Int, CaseIterable, Identifiable, Codable, Sendable {
    case one = 1
    case two = 2

    var id: Int { rawValue }
    var name: String { "Layout \(rawValue)" }

    var other: LayoutID {
        self == .one ? .two : .one
    }

    /// The one color for each layout, the one on the top tiles. The charts, bars and summaries use it too, so
    /// a layout looks the same everywhere.
    var tileFill: Color {
        switch self {
        case .one: Color(hex: 0xFE6A29)
        case .two: Color(hex: 0x007DD5)
        }
    }

    var accent: Color { tileFill }
    var chartColor: Color { tileFill }

    var onTileFill: Color {
        switch self {
        case .one: Color(hex: 0x1A0F08)
        case .two: Color(hex: 0xE3E9F2)
        }
    }

    var floorPlanAssetName: String {
        "FloorPlanLayout\(rawValue)"
    }
}

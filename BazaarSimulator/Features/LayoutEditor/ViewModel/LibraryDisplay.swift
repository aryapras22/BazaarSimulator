import Foundation
import simd

struct LibraryRowDisplay: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case catalog(String)
        case template(BoothTemplate)
    }

    let id: String
    let source: Source
    let title: String
    let detail: String
    let category: CatalogCategory
    let footprint: CatalogFootprint
    let sizeM: SIMD2<Double>
    let openSides: OpenSides
    let seats: [SIMD2<Double>]
    let tint: LegendColor?
}

enum InspectorPanelTab: String, CaseIterable, Hashable, Sendable {
    case library
    case groups

    var title: String {
        switch self {
        case .library: return "Library"
        case .groups: return "Groups"
        }
    }
}

import Foundation
import simd

enum CatalogCategory: String, CaseIterable, Hashable, Sendable {
    case project
    case structure
    case furniture
    case decor

    var title: String {
        switch self {
        case .project: return "From this project"
        case .structure: return "Structure"
        case .furniture: return "Furniture"
        case .decor: return "Decor"
        }
    }
}

enum CatalogFootprint: Hashable, Sendable {
    case rect
    case circle
}

enum CatalogResize: Hashable, Sendable {
    case none
    case uniform
    case free
}

enum CatalogPlacement: Hashable, Sendable {
    case point
    case drawWall
    case door
    case drawArea
}

struct CatalogItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: CatalogCategory
    let kind: LayoutObjectKind
    let sizeM: SIMD2<Double>
    let heightM: Double
    let footprint: CatalogFootprint
    let resize: CatalogResize
    let placement: CatalogPlacement
    let keywords: [String]
    let seats: [SIMD2<Double>]

    func shape(size: SIMD2<Double>, height: Double) -> [ShapePrimitive] {
        ObjectShapes.shape(for: id, size: size, height: height)
    }
}

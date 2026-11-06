import Foundation
import simd

enum ObjectCatalog {
    static let items: [CatalogItem] = structureItems

    static func item(_ id: String) -> CatalogItem? {
        items.first { $0.id == id }
    }

    static func search(_ query: String) -> [CatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            item.name.lowercased().contains(trimmed) ||
            item.keywords.contains { $0.lowercased().contains(trimmed) }
        }
    }

    private static let defaultItemIDsByKind: [LayoutObjectKind: String] = [
        .wall: "wall",
        .block: "block",
        .door: "door",
        .closedArea: "blocked-area",
        .floor: "floor"
    ]

    static func defaultItemID(for kind: LayoutObjectKind) -> String? {
        defaultItemIDsByKind[kind]
    }

    static let structureItems: [CatalogItem] = [
        CatalogItem(
            id: "wall", name: "Wall", category: .structure, kind: .wall,
            sizeM: SIMD2(2.0, 0.2), heightM: 3.0, footprint: .rect,
            resize: .free, placement: .drawWall,
            keywords: ["wall", "partition", "structure", "perimeter"], seats: []
        ),
        CatalogItem(
            id: "partition", name: "Partition", category: .structure, kind: .wall,
            sizeM: SIMD2(2.0, 0.1), heightM: 2.4, footprint: .rect,
            resize: .free, placement: .drawWall,
            keywords: ["partition", "divider", "screen", "wall"], seats: []
        ),
        CatalogItem(
            id: "block", name: "Block", category: .structure, kind: .block,
            sizeM: SIMD2(1.0, 1.0), heightM: 1.2, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["block", "concrete", "barrier", "cube"], seats: []
        ),
        CatalogItem(
            id: "door", name: "Door", category: .structure, kind: .door,
            sizeM: SIMD2(0.9, 0.2), heightM: 2.1, footprint: .rect,
            resize: .none, placement: .door,
            keywords: ["door", "entrance", "exit", "opening"], seats: []
        ),
        CatalogItem(
            id: "double-door", name: "Double door", category: .structure, kind: .door,
            sizeM: SIMD2(1.8, 0.2), heightM: 2.1, footprint: .rect,
            resize: .none, placement: .door,
            keywords: ["double door", "door", "entrance", "exit", "wide"], seats: []
        ),
        CatalogItem(
            id: "gate", name: "Gate", category: .structure, kind: .door,
            sizeM: SIMD2(3.0, 0.2), heightM: 2.1, footprint: .rect,
            resize: .none, placement: .door,
            keywords: ["gate", "entrance", "exit", "barrier", "portal"], seats: []
        ),
        CatalogItem(
            id: "blocked-area", name: "Blocked area", category: .structure, kind: .closedArea,
            sizeM: SIMD2(2.0, 2.0), heightM: 0.05, footprint: .rect,
            resize: .free, placement: .drawArea,
            keywords: ["blocked", "restricted", "closed", "void", "hazard"], seats: []
        ),
        CatalogItem(
            id: "floor", name: "Floor", category: .structure, kind: .floor,
            sizeM: SIMD2(4.0, 4.0), heightM: 0.05, footprint: .rect,
            resize: .free, placement: .drawArea,
            keywords: ["floor", "slab", "ground", "walkable", "deck"], seats: []
        )
    ]
}

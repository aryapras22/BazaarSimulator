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
        .closedArea: "blocked-area"
    ]

    static func defaultItemID(for kind: LayoutObjectKind) -> String? {
        defaultItemIDsByKind[kind]
    }

    static let structureItems: [CatalogItem] = [
        CatalogItem(
            id: "wall", name: "Wall", category: .structure, kind: .wall,
            sizeM: SIMD2(2.0, 0.2), heightM: 3.0, footprint: .rect,
            resize: .free, placement: .drawWall,
            keywords: ["wall", "structure", "perimeter"], seats: []
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
            id: "blocked-area", name: "Blocked area", category: .structure, kind: .closedArea,
            sizeM: SIMD2(2.0, 2.0), heightM: 0.05, footprint: .rect,
            resize: .free, placement: .drawArea,
            keywords: ["blocked", "restricted", "closed", "void", "hazard"], seats: []
        )
    ]
}

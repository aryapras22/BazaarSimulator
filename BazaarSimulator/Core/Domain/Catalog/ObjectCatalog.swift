import Foundation
import simd

enum ObjectCatalog {
    static let items: [CatalogItem] = structureItems + furnitureItems

    /// The only furniture the library offers. Imported seating blocks and other tables still resolve through `items`.
    static let libraryItems: [CatalogItem] = structureItems + furnitureItems.filter { $0.id == "table-rect-4" }

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
        .table: "table-rect-4",
        .seating: FurnitureModels.seatingBlockID
    ]

    static func defaultItemID(for kind: LayoutObjectKind) -> String? {
        defaultItemIDsByKind[kind]
    }

    static let furnitureItems: [CatalogItem] = FurnitureModels.tables.map(tableItem) + [seatingBlockItem]

    private static func tableItem(_ model: TableModel) -> CatalogItem {
        CatalogItem(
            id: model.id, name: model.name, category: .furniture, kind: .table,
            sizeM: model.sizeM, heightM: FurnitureModels.tableHeightM,
            footprint: model.shape == .round ? .circle : .rect,
            resize: .none, placement: .point,
            keywords: ["table", "seating", "chairs", "furniture", model.shape == .round ? "round" : "rectangular"],
            seats: FurnitureModels.seatOffsets(of: model)
        )
    }

    private static let seatingBlockItem = CatalogItem(
        id: FurnitureModels.seatingBlockID, name: "Seating block", category: .furniture, kind: .seating,
        sizeM: FurnitureModels.seatingBlockSizeM, heightM: FurnitureModels.chairHeightM, footprint: .rect,
        resize: .free, placement: .point,
        keywords: ["seating", "audience", "chairs", "rows", "furniture"],
        seats: FurnitureModels.gridOffsets(for: FurnitureModels.seatingBlockSizeM)
    )

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
            id: "column", name: "Column", category: .structure, kind: .block,
            sizeM: SIMD2(0.6, 0.6), heightM: 3.0, footprint: .circle,
            resize: .free, placement: .point,
            keywords: ["column", "pillar", "post", "round", "circle"], seats: []
        ),
        CatalogItem(
            id: "door", name: "Door", category: .structure, kind: .door,
            sizeM: SIMD2(0.9, 0.2), heightM: 2.1, footprint: .rect,
            resize: .none, placement: .door,
            keywords: ["door", "entrance", "exit", "opening"], seats: []
        ),
        CatalogItem(
            id: "blocked-area", name: "Restricted area", category: .structure, kind: .closedArea,
            sizeM: SIMD2(2.0, 2.0), heightM: 0.05, footprint: .rect,
            resize: .free, placement: .drawArea,
            keywords: ["blocked", "restricted", "closed", "void", "hazard"], seats: []
        )
    ]
}

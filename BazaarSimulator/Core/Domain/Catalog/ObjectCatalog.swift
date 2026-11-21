import Foundation
import simd

enum ObjectCatalog {
    static let items: [CatalogItem] = structureItems + furnitureItems + entertainmentItems
    static let columnID = "column"

    /// The furniture the library offers. Imported tables of other models still resolve through `items`.
    static let libraryItems: [CatalogItem] = structureItems
        + furnitureItems.filter { $0.id == "table-rect-4" || $0.id == FurnitureModels.seatingBlockID }

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
        id: FurnitureModels.seatingBlockID, name: "Audience Seating", category: .furniture, kind: .seating,
        sizeM: FurnitureModels.seatingBlockSizeM, heightM: FurnitureModels.chairHeightM, footprint: .rect,
        resize: .free, placement: .point,
        keywords: ["seating", "audience", "chairs", "rows", "furniture"],
        seats: FurnitureModels.gridOffsets(for: FurnitureModels.seatingBlockSizeM)
    )

    static let entertainmentID = "entertainment"

    /// One object for every attraction: a stage, photobooth, competition area or display. The library offers the
    /// plain one. The others are the same object with its type chosen in the inspector.
    static let entertainmentItems: [CatalogItem] = [entertainmentItem(id: entertainmentID, name: "Entertainment")]
        + EntertainmentType.allCases.map { entertainmentItem(id: $0.catalogID, name: $0.displayName) }

    private static func entertainmentItem(id: String, name: String) -> CatalogItem {
        CatalogItem(
            id: id, name: name, category: .entertainment, kind: .entertainment,
            sizeM: SIMD2(4, 3), heightM: 0.6, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["entertainment", "attraction", "stage", "photobooth", "competition", "display"], seats: []
        )
    }

    private static let entertainmentWords = ["stage", "photo", "competition", "lomba", "display"]

    /// Whether a plan label names an attraction, such as "PHOTO BOX" or "Stage".
    static func namesEntertainment(_ label: String) -> Bool {
        let lowered = label.lowercased()
        return entertainmentWords.contains { lowered.contains($0) }
    }

    /// An entertainment object read from a plan, at the default attractiveness.
    static func detectedEntertainment(label: String, placement: Placement) -> LayoutObject {
        LayoutObject(
            kind: .entertainment,
            label: label,
            placement: placement,
            reviewState: .detected,
            catalogID: entertainmentID,
            heightM: item(entertainmentID)?.heightM,
            attractiveness: LayoutObjectKind.entertainment.defaultAttractiveness
        )
    }

    static let structureItems: [CatalogItem] = [
        CatalogItem(
            id: "wall", name: "Wall", category: .structure, kind: .wall,
            sizeM: SIMD2(2.0, 0.2), heightM: 3.0, footprint: .rect,
            resize: .free, placement: .drawWall,
            keywords: ["wall", "structure", "perimeter"], seats: []
        ),
        CatalogItem(
            id: "block", name: "Object", category: .structure, kind: .block,
            sizeM: SIMD2(2.0, 2.0), heightM: 1.2, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["object", "block", "concrete", "barrier", "cube"], seats: []
        ),
        CatalogItem(
            id: columnID, name: "Column", category: .structure, kind: .block,
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

/// What an attraction is. It picks the 3D model, and is stored as the object's catalog ID the way a table's model is.
nonisolated enum EntertainmentType: String, CaseIterable, Hashable, Sendable {
    case stage
    case photobooth
    case informationDesk
    case other
    case disabled

    var displayName: String {
        switch self {
        case .stage: "Stage"
        case .photobooth: "Photobooth"
        case .informationDesk: "Information Desk"
        case .other: "Others"
        case .disabled: "Disabled"
        }
    }

    var catalogID: String {
        "entertainment-\(rawValue)"
    }

    var isInOthersSection: Bool {
        self == .informationDesk || self == .other || self == .disabled
    }

    /// The type chosen in the inspector. An object that never had one chosen, such as one read from a plan, carries
    /// the plain entertainment ID, so its type is read from its label.
    static func resolve(catalogID: String?, label: String) -> EntertainmentType {
        if let chosen = allCases.first(where: { $0.catalogID == catalogID }) {
            return chosen
        }
        let lowered = label.lowercased()
        if lowered.contains("info") { return .informationDesk }
        if lowered.contains("photo") { return .photobooth }
        if ["competition", "lomba", "display"].contains(where: lowered.contains) { return .other }
        return .stage
    }
}

import Foundation
import simd

enum ObjectCatalog {
    static let items: [CatalogItem] = structureItems + furnitureItems + decorItems

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

    static func defaultItemID(for kind: LayoutObjectKind) -> String? {
        switch kind {
        case .wall: return "wall"
        case .rail: return "rail"
        case .block: return "block"
        case .pillar: return "pillar-round"
        case .door: return "door"
        case .closedArea: return "blocked-area"
        case .table: return "table-4"
        case .stage: return "stage"
        case .fixture: return "planter"
        case .booth, .audienceArea: return nil
        }
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
            id: "rail", name: "Rail", category: .structure, kind: .rail,
            sizeM: SIMD2(2.0, 0.05), heightM: 1.0, footprint: .rect,
            resize: .free, placement: .drawWall,
            keywords: ["rail", "barrier", "fence", "queue"], seats: []
        ),
        CatalogItem(
            id: "block", name: "Block", category: .structure, kind: .block,
            sizeM: SIMD2(1.0, 1.0), heightM: 1.2, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["block", "concrete", "barrier", "cube"], seats: []
        ),
        CatalogItem(
            id: "pillar-round", name: "Pillar", category: .structure, kind: .pillar,
            sizeM: SIMD2(0.6, 0.6), heightM: 3.0, footprint: .circle,
            resize: .uniform, placement: .point,
            keywords: ["pillar", "column", "post", "structure", "round"], seats: []
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
            id: "stage", name: "Stage", category: .structure, kind: .stage,
            sizeM: SIMD2(4.0, 3.0), heightM: 0.8, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["stage", "platform", "performance", "deck"], seats: []
        ),
        CatalogItem(
            id: "stage-extension", name: "Stage extension", category: .structure, kind: .stage,
            sizeM: SIMD2(3.0, 3.0), heightM: 0.8, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["stage", "extension", "riser", "deck"], seats: []
        )
    ]

    static let furnitureItems: [CatalogItem] = [
        CatalogItem(
            id: "table-2", name: "Table for 2", category: .furniture, kind: .table,
            sizeM: SIMD2(0.8, 0.8), heightM: 0.75, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["table", "rectangular", "square", "cafe", "seats", "dining"],
            seats: []
        ),
        CatalogItem(
            id: "table-4", name: "Table for 4", category: .furniture, kind: .table,
            sizeM: SIMD2(1.2, 0.8), heightM: 0.75, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["table", "rectangular", "dining", "restaurant", "seats"],
            seats: []
        ),
        CatalogItem(
            id: "table-round-4", name: "Round table for 4", category: .furniture, kind: .table,
            sizeM: SIMD2(1.0, 1.0), heightM: 0.75, footprint: .circle,
            resize: .uniform, placement: .point,
            keywords: ["table", "round", "dining", "cafe", "seats"],
            seats: [SIMD2(0, 0.35), SIMD2(0.35, 0), SIMD2(0, -0.35), SIMD2(-0.35, 0)]
        ),
        CatalogItem(
            id: "table-round-6", name: "Round table for 6", category: .furniture, kind: .table,
            sizeM: SIMD2(1.524, 1.524), heightM: 0.75, footprint: .circle,
            resize: .uniform, placement: .point,
            keywords: ["table", "round", "banquet", "dining", "seats"],
            seats: (0..<6).map { index in
                let angle = Double(index) * (.pi / 3.0)
                return SIMD2(cos(angle) * 0.55, sin(angle) * 0.55)
            }
        ),
        CatalogItem(
            id: "table-round-8", name: "Round table for 8", category: .furniture, kind: .table,
            sizeM: SIMD2(1.83, 1.83), heightM: 0.75, footprint: .circle,
            resize: .uniform, placement: .point,
            keywords: ["table", "round", "banquet", "large", "seats"],
            seats: (0..<8).map { index in
                let angle = Double(index) * (.pi / 4.0)
                return SIMD2(cos(angle) * 0.7, sin(angle) * 0.7)
            }
        ),
        CatalogItem(
            id: "table-rect-6ft", name: "Rectangular table 6 ft", category: .furniture, kind: .table,
            sizeM: SIMD2(1.83, 0.76), heightM: 0.75, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["table", "trestle", "rectangular", "meeting"],
            seats: [
                SIMD2(-0.55, 0.25), SIMD2(0, 0.25), SIMD2(0.55, 0.25),
                SIMD2(-0.55, -0.25), SIMD2(0, -0.25), SIMD2(0.55, -0.25)
            ]
        ),
        CatalogItem(
            id: "table-bar", name: "Bar table", category: .furniture, kind: .table,
            sizeM: SIMD2(0.6, 0.6), heightM: 1.1, footprint: .circle,
            resize: .none, placement: .point,
            keywords: ["table", "bar", "high", "cocktail", "standing"], seats: []
        ),
        CatalogItem(
            id: "bench", name: "Bench", category: .furniture, kind: .table,
            sizeM: SIMD2(1.8, 0.4), heightM: 0.45, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["bench", "seat", "seating", "chair"],
            seats: [SIMD2(-0.5, 0), SIMD2(0, 0), SIMD2(0.5, 0)]
        ),
        CatalogItem(
            id: "counter", name: "Counter", category: .furniture, kind: .fixture,
            sizeM: SIMD2(2.0, 0.6), heightM: 1.1, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["counter", "bar", "reception", "desk", "service"], seats: []
        ),
        CatalogItem(
            id: "kiosk", name: "Kiosk", category: .furniture, kind: .fixture,
            sizeM: SIMD2(0.6, 0.5), heightM: 1.6, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["kiosk", "terminal", "information", "pos"], seats: []
        )
    ]

    static let decorItems: [CatalogItem] = [
        CatalogItem(
            id: "planter", name: "Planter", category: .decor, kind: .fixture,
            sizeM: SIMD2(1.0, 0.5), heightM: 0.6, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["planter", "plant", "greenery", "decor", "flower"], seats: []
        ),
        CatalogItem(
            id: "floor-sign", name: "Floor sign", category: .decor, kind: .fixture,
            sizeM: SIMD2(0.6, 0.4), heightM: 1.6, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["sign", "direction", "board", "standing"], seats: []
        ),
        CatalogItem(
            id: "banner-stand", name: "Banner stand", category: .decor, kind: .fixture,
            sizeM: SIMD2(0.8, 0.3), heightM: 2.0, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["banner", "stand", "poster", "advertising", "decor"], seats: []
        ),
        CatalogItem(
            id: "bin", name: "Bin", category: .decor, kind: .fixture,
            sizeM: SIMD2(0.4, 0.4), heightM: 0.8, footprint: .circle,
            resize: .none, placement: .point,
            keywords: ["bin", "trash", "waste", "recycling"], seats: []
        ),
        CatalogItem(
            id: "display-case", name: "Display case", category: .decor, kind: .fixture,
            sizeM: SIMD2(1.2, 0.6), heightM: 1.0, footprint: .rect,
            resize: .free, placement: .point,
            keywords: ["display", "case", "showcase", "exhibit", "cabinet"], seats: []
        ),
        CatalogItem(
            id: "claw-machine", name: "Claw machine", category: .decor, kind: .fixture,
            sizeM: SIMD2(0.9, 0.9), heightM: 1.9, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["claw", "machine", "arcade", "game"], seats: []
        ),
        CatalogItem(
            id: "photo-booth", name: "Photo booth", category: .decor, kind: .fixture,
            sizeM: SIMD2(2.0, 2.0), heightM: 2.2, footprint: .rect,
            resize: .none, placement: .point,
            keywords: ["photo", "booth", "camera", "interactive"], seats: []
        )
    ]
}

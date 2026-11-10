import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct ObjectCatalogTests {
    @Test("Catalog items have unique IDs")
    func uniqueItemIDs() {
        let ids = ObjectCatalog.items.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == ObjectCatalog.structureItems.count + ObjectCatalog.furnitureItems.count)
        #expect(uniqueIDs.count == ids.count)
    }

    @Test("Item search matches names and keywords case-insensitively")
    func itemSearch() {
        let gateResults = ObjectCatalog.search("DOOR")
        #expect(gateResults.map(\.id) == ["door"])

        let emptyResults = ObjectCatalog.search("   ")
        #expect(emptyResults.count == ObjectCatalog.items.count)

        let nonexistent = ObjectCatalog.search("xyz123nonexistent")
        #expect(nonexistent.isEmpty)
    }

    @Test("Default item IDs map to expected catalog items")
    func defaultItemIDs() {
        #expect(ObjectCatalog.defaultItemID(for: .wall) == "wall")
        #expect(ObjectCatalog.defaultItemID(for: .block) == "block")
        #expect(ObjectCatalog.defaultItemID(for: .door) == "door")
        #expect(ObjectCatalog.defaultItemID(for: .closedArea) == "blocked-area")
        #expect(ObjectCatalog.defaultItemID(for: .booth) == nil)
    }

    @Test("Every catalog item's primitives stay strictly inside its footprint and height")
    func primitivesStayInsideFootprint() {
        let tolerance = 0.001
        for item in ObjectCatalog.items {
            let primitives = item.shape(size: item.sizeM, height: item.heightM)
            #expect(!primitives.isEmpty, "Item \(item.id) should produce primitives")

            // The chairs of a table stand just outside its top, and count as part of the item.
            let chairReach = item.kind == .table ? FurnitureModels.chairGapM + FurnitureModels.chairSizeM.x : 0
            let halfW = item.sizeM.x / 2.0 + chairReach
            let halfD = item.sizeM.y / 2.0 + chairReach

            for primitive in primitives {
                let bounds = primitive.bounds
                #expect(
                    bounds.min.x >= -halfW - tolerance,
                    "Item \(item.id) primitive \(primitive) exceeds min x (-halfW: \(-halfW), got: \(bounds.min.x))"
                )
                #expect(
                    bounds.max.x <= halfW + tolerance,
                    "Item \(item.id) primitive \(primitive) exceeds max x (halfW: \(halfW), got: \(bounds.max.x))"
                )
                #expect(
                    bounds.min.z >= -halfD - tolerance,
                    "Item \(item.id) primitive \(primitive) exceeds min z (-halfD: \(-halfD), got: \(bounds.min.z))"
                )
                #expect(
                    bounds.max.z <= halfD + tolerance,
                    "Item \(item.id) primitive \(primitive) exceeds max z (halfD: \(halfD), got: \(bounds.max.z))"
                )
                #expect(
                    bounds.min.y >= -tolerance,
                    "Item \(item.id) primitive \(primitive) has negative y (got: \(bounds.min.y))"
                )
                #expect(
                    bounds.max.y <= item.heightM + tolerance,
                    "Item \(item.id) primitive \(primitive) exceeds height (\(item.heightM), got: \(bounds.max.y))"
                )
            }
        }
    }
}

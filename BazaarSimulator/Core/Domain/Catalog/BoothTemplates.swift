import Foundation
import simd

struct BoothTemplate: Identifiable, Hashable, Sendable {
    var id: String {
        let categoryString = categoryID?.uuidString ?? "none"
        return "\(categoryString)-\(sizeKey.shortM)x\(sizeKey.longM)"
    }
    let categoryID: LegendEntry.ID?
    let sizeKey: BoothSizeKey
    let count: Int
}

enum BoothTemplates {
    /// Every category crossed with every booth size key used in the layouts, with counts.
    /// A legend category without booths gets one template at the most common size.
    static func templates(layouts: [Layout], legend: Legend) -> [BoothTemplate] {
        var counts: [TemplateKey: Int] = [:]
        var sizeTotals: [BoothSizeKey: Int] = [:]

        for layout in layouts {
            for object in layout.objects where object.kind == .booth {
                let sizeKey = BoothGrouping.sizeKey(of: object.placement)
                let key = TemplateKey(categoryID: object.categoryID, sizeKey: sizeKey)
                counts[key, default: 0] += 1
                sizeTotals[sizeKey, default: 0] += 1
            }
        }

        let mostCommonSize = sizeTotals
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .first?.key ?? BoothSizeKey(shortM: 2.5, longM: 2.5)

        var result = counts.map { key, count in
            BoothTemplate(categoryID: key.categoryID, sizeKey: key.sizeKey, count: count)
        }

        let categoriesWithBooths = Set(result.compactMap(\.categoryID))
        for entry in legend.entries where !categoriesWithBooths.contains(entry.id) {
            result.append(BoothTemplate(categoryID: entry.id, sizeKey: mostCommonSize, count: 0))
        }

        let orderIndex: [LegendEntry.ID: Int] = Dictionary(
            uniqueKeysWithValues: legend.entries.enumerated().map { ($1.id, $0) }
        )

        result.sort { lhs, rhs in
            let lhsOrder = lhs.categoryID.flatMap { orderIndex[$0] } ?? Int.max
            let rhsOrder = rhs.categoryID.flatMap { orderIndex[$0] } ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }
            return lhs.sizeKey < rhs.sizeKey
        }

        return result
    }

    private struct TemplateKey: Hashable {
        let categoryID: LegendEntry.ID?
        let sizeKey: BoothSizeKey
    }
}

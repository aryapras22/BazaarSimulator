import Foundation
import simd

struct BoothTemplate: Identifiable, Hashable, Sendable {
    var id: String { "\(sizeKey.shortM)x\(sizeKey.longM)" }
    let boothType: BoothType?
    let sizeKey: BoothSizeKey
    let count: Int
}

enum BoothTemplates {
    /// The one library booth: no type, at the most common booth size in the layouts, with the number of booths placed.
    static func standard(layouts: [Layout]) -> BoothTemplate {
        var sizeTotals: [BoothSizeKey: Int] = [:]
        for layout in layouts {
            for object in layout.objects where object.kind == .booth {
                sizeTotals[BoothGrouping.sizeKey(of: object.placement), default: 0] += 1
            }
        }
        let mostCommonSize = sizeTotals
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .first?.key ?? BoothSizeKey(shortM: 2.5, longM: 2.5)
        return BoothTemplate(boothType: nil, sizeKey: mostCommonSize, count: sizeTotals.values.reduce(0, +))
    }
}

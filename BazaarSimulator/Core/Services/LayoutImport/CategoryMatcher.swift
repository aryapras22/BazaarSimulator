import Foundation

enum CategoryMatcher {
    private static let foodKeywords = ["food", "f&b", "fnb"]

    static func entry(for type: String, in legend: Legend) -> LegendEntry.ID? {
        guard type.lowercased() == "fnb" else { return nil }
        return foodEntry(in: legend)?.id
    }

    /// Default category per booth label. `fnb` booths get the food entry. `goods` booths get a
    /// non-food entry per name prefix, prefixes sorted alphabetically, cycling through the entries.
    static func defaultCategories(for booths: [BazaarBoothDTO], in legend: Legend) -> [String: LegendEntry.ID] {
        let food = foodEntry(in: legend)
        let nonFood = legend.entries.filter { !isFood($0) }
        let goodsPrefixes = Set(
            booths.filter { !isFoodType($0.type) }.map { BoothGrouping.namePrefix(of: $0.id) }
        ).sorted()
        var entryByPrefix: [String: LegendEntry.ID] = [:]
        if !nonFood.isEmpty {
            for (index, prefix) in goodsPrefixes.enumerated() {
                entryByPrefix[prefix] = nonFood[index % nonFood.count].id
            }
        }
        var result: [String: LegendEntry.ID] = [:]
        for booth in booths {
            if isFoodType(booth.type) {
                if let food { result[booth.id] = food.id }
            } else if let entry = entryByPrefix[BoothGrouping.namePrefix(of: booth.id)] {
                result[booth.id] = entry
            }
        }
        return result
    }

    private static func isFoodType(_ type: String) -> Bool {
        type.lowercased() == "fnb"
    }

    private static func foodEntry(in legend: Legend) -> LegendEntry? {
        legend.entries.first(where: isFood)
    }

    /// The booth type a legend entry starts with before the user picks one.
    static func defaultType(for entry: LegendEntry) -> BoothType {
        isFood(entry) ? .fnb : .goods
    }

    private static func isFood(_ entry: LegendEntry) -> Bool {
        let lowered = entry.name.lowercased()
        return foodKeywords.contains { lowered.contains($0) }
    }
}

import Foundation

enum CategoryMatcher {
    private static let foodKeywords = ["food", "f&b", "fnb"]

    static func entry(for type: String, in legend: Legend) -> LegendEntry.ID? {
        guard type.lowercased() == "fnb" else { return nil }
        return legend.entries.first { entry in
            let lowered = entry.name.lowercased()
            return foodKeywords.contains { lowered.contains($0) }
        }?.id
    }
}

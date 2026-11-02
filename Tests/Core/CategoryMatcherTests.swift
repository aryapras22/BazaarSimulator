import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct CategoryMatcherTests {
    @Test("fnb matches Food & Beverage, F&B, and FNB case-insensitively")
    func fnbMatchesFoodNames() {
        let color = LegendColor(red: 1, green: 0, blue: 0)
        for foodName in ["Food & Beverage", "F&B", "FNB", "food court"] {
            let foodEntry = LegendEntry(name: foodName, color: color)
            let fashionEntry = LegendEntry(name: "Fashion", color: color)
            let legend = Legend(entries: [fashionEntry, foodEntry])

            let matched = CategoryMatcher.entry(for: "fnb", in: legend)

            #expect(matched == foodEntry.id)
        }
    }

    @Test("goods matches nothing")
    func goodsMatchesNothing() {
        let color = LegendColor(red: 1, green: 0, blue: 0)
        let legend = Legend(entries: [
            LegendEntry(name: "Food & Beverage", color: color),
            LegendEntry(name: "Fashion & Beauty", color: color),
            LegendEntry(name: "Lifestyle & Hobbies", color: color)
        ])

        let matched = CategoryMatcher.entry(for: "goods", in: legend)

        #expect(matched == nil)
    }

    @Test("An empty legend matches nothing")
    func emptyLegendMatchesNothing() {
        let matched = CategoryMatcher.entry(for: "fnb", in: Legend())

        #expect(matched == nil)
    }
}

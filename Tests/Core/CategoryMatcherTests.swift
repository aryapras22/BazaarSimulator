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

    @Test("Annyeong default categories: FNB 42, Fashion 128, Lifestyle 39, none unassigned")
    func annyeongDefaultCategoryCounts() throws {
        let counts = try categoryCounts(layoutFile: "annyeong-market-layout")

        #expect(counts == ["FNB": 42, "Fashion": 128, "Lifestyle & Hobbies": 39, "Unassigned": 0])
    }

    @Test("Beyond default categories: FNB 70, Fashion 37, Lifestyle 47, none unassigned")
    func beyondDefaultCategoryCounts() throws {
        let counts = try categoryCounts(layoutFile: "beyond-market-layout")

        #expect(counts == ["FNB": 70, "Fashion": 37, "Lifestyle & Hobbies": 47, "Unassigned": 0])
    }

    @Test("Every booth in one name group gets the same category")
    func nameGroupsShareACategory() throws {
        let layout = try mappedLayout("beyond-market-layout", legend: Self.fakeQueueLegend)

        for group in BoothGrouping.nameGroups(in: layout) {
            let categories = Set(group.memberIDs.compactMap { id in layout.objects.first { $0.id == id }?.categoryID })
            #expect(categories.count == 1)
        }
    }

    @Test("A food-only legend leaves goods unassigned, and an empty legend leaves everything unassigned")
    func missingEntriesLeaveBoothsUnassigned() throws {
        let foodOnly = Legend(entries: [LegendEntry(name: "FNB", color: Self.color)])

        let foodOnlyLayout = try mappedLayout("annyeong-market-layout", legend: foodOnly)
        let emptyLayout = try mappedLayout("annyeong-market-layout", legend: Legend())

        let foodOnlyBooths = foodOnlyLayout.objects.filter { $0.kind == .booth }
        #expect(foodOnlyBooths.filter { $0.categoryID != nil }.count == 42)
        #expect(emptyLayout.objects.filter { $0.kind == .booth && $0.categoryID != nil }.isEmpty)
    }

    @Test("An empty legend matches nothing")
    func emptyLegendMatchesNothing() {
        let matched = CategoryMatcher.entry(for: "fnb", in: Legend())

        #expect(matched == nil)
    }

    private static let color = LegendColor(red: 1, green: 0, blue: 0)
    private static let fakeQueueLegend = Legend(entries: [
        LegendEntry(name: "FNB", color: color),
        LegendEntry(name: "Fashion", color: color),
        LegendEntry(name: "Lifestyle & Hobbies", color: color)
    ])

    private func mappedLayout(_ file: String, legend: Legend) throws -> Layout {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: file)
        return MockLayoutMapper.layout(from: dto, legend: legend)
    }

    private func categoryCounts(layoutFile: String) throws -> [String: Int] {
        let layout = try mappedLayout(layoutFile, legend: Self.fakeQueueLegend)
        var counts = ["Unassigned": 0]
        for booth in layout.objects where booth.kind == .booth {
            let name = Self.fakeQueueLegend.entries.first { $0.id == booth.categoryID }?.name ?? "Unassigned"
            counts[name, default: 0] += 1
        }
        return counts
    }
}

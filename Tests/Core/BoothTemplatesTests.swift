import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct BoothTemplatesTests {
    private let testLegend = Legend(entries: [
        LegendEntry(
            name: "Food & Beverage",
            color: LegendColor(red: 222 / 255.0, green: 42 / 255.0, blue: 42 / 255.0)
        ),
        LegendEntry(
            name: "Fashion & Beauty",
            color: LegendColor(red: 42 / 255.0, green: 222 / 255.0, blue: 49 / 255.0)
        ),
        LegendEntry(
            name: "Lifestyle & Hobbies",
            color: LegendColor(red: 244 / 255.0, green: 220 / 255.0, blue: 48 / 255.0)
        )
    ])

    @Test("Both layouts together produce 13 templates with exact counts")
    func bothLayoutsTemplates() throws {
        let annyeong = try loadLayout("annyeong-market-layout", legend: testLegend)
        let beyond = try loadLayout("beyond-market-layout", legend: testLegend)

        let templates = BoothTemplates.templates(layouts: [annyeong, beyond], legend: testLegend)

        #expect(templates.count == 13)

        let fnbID = testLegend.entries[0].id
        let fashionID = testLegend.entries[1].id
        let lifestyleID = testLegend.entries[2].id

        let counts: [String: Int] = Dictionary(
            uniqueKeysWithValues: templates.map { template in
                let categoryName: String
                if template.categoryID == fnbID {
                    categoryName = "FNB"
                } else if template.categoryID == fashionID {
                    categoryName = "Fashion"
                } else if template.categoryID == lifestyleID {
                    categoryName = "Lifestyle"
                } else {
                    categoryName = "Unassigned"
                }
                let key = "\(categoryName) \(template.sizeKey.shortM)x\(template.sizeKey.longM)"
                return (key, template.count)
            }
        )

        #expect(counts["FNB 2.0x2.0"] == 94)
        #expect(counts["FNB 2.0x3.0"] == 18)

        #expect(counts["Fashion 2.0x2.0"] == 21)
        #expect(counts["Fashion 2.0x3.0"] == 4)
        #expect(counts["Fashion 2.5x2.5"] == 120)
        #expect(counts["Fashion 2.5x5.0"] == 8)
        #expect(counts["Fashion 3.0x4.0"] == 9)
        #expect(counts["Fashion 5.0x5.0"] == 3)

        #expect(counts["Lifestyle 2.0x2.0"] == 18)
        #expect(counts["Lifestyle 2.5x2.5"] == 30)
        #expect(counts["Lifestyle 3.0x3.0"] == 26)
        #expect(counts["Lifestyle 4.0x4.0"] == 3)
        #expect(counts["Lifestyle 5.0x5.0"] == 9)
    }

    @Test("Annyeong alone yields 5 templates and Beyond alone yields 9")
    func singleLayoutTemplates() throws {
        let annyeong = try loadLayout("annyeong-market-layout", legend: testLegend)
        let beyond = try loadLayout("beyond-market-layout", legend: testLegend)

        let annyeongTemplates = BoothTemplates.templates(layouts: [annyeong], legend: testLegend)
        #expect(annyeongTemplates.count == 5)

        let beyondTemplates = BoothTemplates.templates(layouts: [beyond], legend: testLegend)
        #expect(beyondTemplates.count == 9)
    }

    @Test("Legend entry without booths gets one template at the most common size")
    func emptyCategoryGetsTemplateAtMostCommonSize() throws {
        var extendedLegend = testLegend
        let booksEntry = LegendEntry(
            name: "Books & Stationery",
            color: LegendColor(red: 0.2, green: 0.4, blue: 0.8)
        )
        extendedLegend.entries.append(booksEntry)

        let annyeong = try loadLayout("annyeong-market-layout", legend: testLegend)
        let beyond = try loadLayout("beyond-market-layout", legend: testLegend)

        let templates = BoothTemplates.templates(
            layouts: [annyeong, beyond],
            legend: extendedLegend
        )

        #expect(templates.count == 14)

        let booksTemplate = try #require(templates.first { $0.categoryID == booksEntry.id })
        #expect(booksTemplate.sizeKey == BoothSizeKey(shortM: 2.5, longM: 2.5))
        #expect(booksTemplate.count == 0)
    }

    private func loadLayout(_ name: String, legend: Legend) throws -> Layout {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: name)
        return MockLayoutMapper.layout(from: dto, legend: legend)
    }
}

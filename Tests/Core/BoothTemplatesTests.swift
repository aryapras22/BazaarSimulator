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

    @Test("Both layouts give one booth template at the most common size, counting every booth")
    func oneTemplateForAllBooths() throws {
        let annyeong = try loadLayout("annyeong-market-layout", legend: testLegend)
        let beyond = try loadLayout("beyond-market-layout", legend: testLegend)

        let template = BoothTemplates.standard(layouts: [annyeong, beyond])

        #expect(template.boothType == nil)
        #expect(template.sizeKey == BoothSizeKey(shortM: 2.5, longM: 2.5))
        #expect(template.count == 94 + 18 + 21 + 4 + 120 + 8 + 9 + 3 + 18 + 30 + 26 + 3 + 9)
    }

    @Test("Without booths the template is 2.5 x 2.5 with a count of zero")
    func emptyLayoutsTemplate() {
        let template = BoothTemplates.standard(layouts: [])
        #expect(template.sizeKey == BoothSizeKey(shortM: 2.5, longM: 2.5))
        #expect(template.count == 0)
    }

    private func loadLayout(_ name: String, legend: Legend) throws -> Layout {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: name)
        return MockLayoutMapper.layout(from: dto, legend: legend)
    }
}

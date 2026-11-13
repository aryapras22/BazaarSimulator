import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct MockLayoutValidationTests {
    @Test("Annyeong validates with no issues")
    func annyeongValidatesWithNoIssues() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "annyeong-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)

        #expect(LayoutValidator.issues(in: layout).isEmpty)
    }

    @Test(
        "More Market layouts validate with no issues",
        arguments: [
        "more-market-i-layout",
        "more-market-ii-layout",
        "more-market-iii-layout",
        "more-market-iv-layout",
        "more-market-v-layout",
        "more-market-vi-layout",
        "more-market-viii-layout"
        ]
    )
    func moreMarketValidatesWithNoIssues(fileName: String) throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: fileName)
        let layout = MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)

        #expect(LayoutValidator.issues(in: layout).isEmpty)
    }

    @Test("Beyond validates with no issues")
    func beyondValidatesWithNoIssues() throws {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: "beyond-market-layout")
        let layout = MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)

        #expect(LayoutValidator.issues(in: layout).isEmpty)
    }
}

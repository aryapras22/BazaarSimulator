import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct BoothGroupingTests {
    @Test("Name prefix is the uppercased leading letters, or # without letters")
    func namePrefixes() {
        #expect(BoothGrouping.namePrefix(of: "A12") == "A")
        #expect(BoothGrouping.namePrefix(of: "XX2") == "XX")
        #expect(BoothGrouping.namePrefix(of: "f3") == "F")
        #expect(BoothGrouping.namePrefix(of: "12") == "#")
    }

    @Test("Size keys round to 0.5 m and put the short side first")
    func sizeKeys() {
        let noisy = Placement(center: .zero, sizeM: SIMD2(2.49, 2.53))
        let wide = Placement(center: .zero, sizeM: SIMD2(5.0, 2.5))
        let rotated = Placement(center: .zero, sizeM: SIMD2(2.5, 5.0), rotationRadians: .pi / 2)

        #expect(BoothGrouping.sizeKey(of: noisy) == BoothSizeKey(shortM: 2.5, longM: 2.5))
        #expect(BoothGrouping.sizeKey(of: wide) == BoothSizeKey(shortM: 2.5, longM: 5.0))
        #expect(BoothGrouping.sizeKey(of: rotated) == BoothGrouping.sizeKey(of: wide))
    }

    @Test("Annyeong groups by name and size")
    func annyeongGroups() throws {
        let layout = try mockLayout("annyeong-market-layout")

        let names = BoothGrouping.nameGroups(in: layout)
        let sizes = BoothGrouping.sizeGroups(in: layout)

        #expect(names.map(\.title) == ["A", "B", "C", "F", "I"])
        #expect(names.map(\.memberIDs.count) == [112, 30, 16, 42, 9])
        #expect(sizes.map(\.memberIDs.count) == [150, 42, 9, 8])
        #expect(names.first?.clusters.count == 13)
    }

    @Test("Beyond groups by size")
    func beyondSizeGroups() throws {
        let layout = try mockLayout("beyond-market-layout")

        let sizes = BoothGrouping.sizeGroups(in: layout)

        #expect(sizes.map(\.memberIDs.count) == [91, 26, 22, 9, 3, 3])
    }

    private func mockLayout(_ name: String) throws -> Layout {
        let dto = try MockDataStore.load(BazaarLayoutDTO.self, from: name)
        return MockLayoutMapper.layout(from: dto, legend: PreviewLayouts.sampleLegend)
    }
}

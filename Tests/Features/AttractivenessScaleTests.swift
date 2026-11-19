import Testing
@testable import BazaarSimulator

@Suite
struct AttractivenessScaleTests {
    @Test("Opacity rises with attractiveness from the minimum to full")
    func opacityRises() {
        let values = [1.0, 2, 3, 4, 5].map(AttractivenessScale.opacity(for:))
        #expect(values.first == AttractivenessScale.minimumOpacity)
        #expect(values.last == 1)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 < $1 })
        #expect((0.15...0.4).contains(AttractivenessScale.minimumOpacity))
    }

    @Test("Values outside the range clamp to its ends")
    func valuesClamp() {
        #expect(AttractivenessScale.opacity(for: 0) == AttractivenessScale.minimumOpacity)
        #expect(AttractivenessScale.opacity(for: 9) == 1)
    }
}

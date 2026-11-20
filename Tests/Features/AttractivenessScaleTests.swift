import Testing
@testable import BazaarSimulator

@Suite
struct AttractivenessScaleTests {
    @Test("Step maps 1 through 5 to indices 0 through 4")
    func stepsMapOneToFive() {
        let steps = [1.0, 2, 3, 4, 5].map(AttractivenessScale.step(for:))
        #expect(steps == [0, 1, 2, 3, 4])
    }

    @Test("Fractional values round to the nearest step")
    func fractionalValuesRound() {
        #expect(AttractivenessScale.step(for: 2.6) == 2)
    }

    @Test("Values outside the range clamp to its ends")
    func valuesClamp() {
        #expect(AttractivenessScale.step(for: 0) == 0)
        #expect(AttractivenessScale.step(for: 9) == 4)
    }

    @Test("Color uses the matching step from the five-shade palette")
    func colorMatchesStep() {
        #expect(Palette.attractivenessSteps.count == 5)
        let colors = [1.0, 2, 3, 4, 5].map(AttractivenessScale.color(for:))
        #expect(colors == Palette.attractivenessSteps)
    }
}

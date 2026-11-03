import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct DimensionInputTests {
    @Test("Two-decimal values keep their digits")
    func twoDecimalValuesKeepDigits() {
        #expect(DimensionInput.text(for: 2.53) == "2.53")
        #expect(DimensionInput.text(for: 2.5) == "2.5")
        #expect(DimensionInput.text(for: 2.0) == "2")
    }

    @Test("Comma decimals parse")
    func commaDecimalsParse() {
        #expect(DimensionInput.value(from: "2,5") == 2.5)
    }

    @Test("Unchanged text does not change the value")
    func unchangedTextDoesNotChangeValue() {
        #expect(!DimensionInput.changesValue("2.53", current: 2.53))
        #expect(DimensionInput.changesValue("2.5", current: 2.53))
    }
}

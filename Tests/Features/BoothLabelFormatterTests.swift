import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct BoothLabelFormatterTests {
    @Test("Inserts a hyphen between the letter prefix and number suffix")
    func formatsBoothLabels() {
        #expect(BoothLabelFormatter.display("B7") == "B-7")
        #expect(BoothLabelFormatter.display("XX2") == "XX-2")
        #expect(BoothLabelFormatter.display("A12") == "A-12")
        #expect(BoothLabelFormatter.display("B-7") == "B-7")
        #expect(BoothLabelFormatter.display("STAGE") == "STAGE")
    }
}

import Testing
@testable import BazaarSimulator

@Suite
struct PlanPrintedTextTests {
    @Test("Printed words name the longest legend class they spell, across lines and letter case")
    func namesPrintedClass() {
        let names = ["Stage", "Stage front", "Area Korpet", "Booth, goods (3 x 2 m)"]

        #expect(PlanPrintedText.className(printedIn: ["AREA", "KORPET", "8m x 5m"], among: names) == "Area Korpet")
        #expect(PlanPrintedText.className(printedIn: ["STAGE FRONT"], among: names) == "Stage front")
        #expect(PlanPrintedText.className(printedIn: ["TOILET"], among: names) == nil)
        #expect(PlanPrintedText.className(printedIn: [], among: names) == nil)
    }

    @Test("A booth number is the first short number among the words, with or without letters in front")
    func readsBoothNumber() {
        #expect(PlanPrintedText.boothNumber(in: ["142 4x 3"]) == "142")
        #expect(PlanPrintedText.boothNumber(in: ["LL", "74"]) == "74")
        #expect(PlanPrintedText.boothNumber(in: ["gd29"]) == "GD29")
        #expect(PlanPrintedText.boothNumber(in: ["PHOTOBOOTH", "2024"]) == nil)
    }
}

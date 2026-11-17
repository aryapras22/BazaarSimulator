import Testing
@testable import BazaarSimulator

@Suite("SeverityGradeTests")
struct SeverityGradeTests {
    @Test("Each grade ends at its set density: A 0.08, B 0.27, C 0.45, D 0.72, E 1.8")
    func gradeLimits() {
        #expect(SeverityGrade.allCases.map(\.upperDensity) == [0.08, 0.27, 0.45, 0.72, 1.8, nil])
        #expect(SeverityGrade.allCases.map(\.lowerDensity) == [0, 0.08, 0.27, 0.45, 0.72, 1.8])
    }

    @Test("A density is graded by the first grade that holds it, and the limit itself belongs to the lower grade")
    func grading() {
        #expect(SeverityGrade.grade(forDensity: 0) == .a)
        #expect(SeverityGrade.grade(forDensity: 0.08) == .a)
        #expect(SeverityGrade.grade(forDensity: 0.081) == .b)
        #expect(SeverityGrade.grade(forDensity: 0.27) == .b)
        #expect(SeverityGrade.grade(forDensity: 0.45) == .c)
        #expect(SeverityGrade.grade(forDensity: 0.72) == .d)
        #expect(SeverityGrade.grade(forDensity: 1.8) == .e)
        #expect(SeverityGrade.grade(forDensity: 1.81) == .f)
        #expect(SeverityGrade.grade(forDensity: 40) == .f)
    }

    @Test("People are stuck from grade E, above 0.72 per m²")
    func stuckStartsAtE() {
        #expect(SeverityGrade.heavyThreshold == 0.72)
        #expect(SeverityGrade.grade(forDensity: SeverityGrade.heavyThreshold + 0.01) == .e)
    }

    @Test("The range shown for each grade matches its limits")
    func rangeText() {
        #expect(SeverityGrade.allCases.map(\.rangeText) ==
                ["up to 0.08", "0.08–0.27", "0.27–0.45", "0.45–0.72", "0.72–1.8", "over 1.8"])
    }
}

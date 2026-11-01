import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ImportRowFormatterTests")
struct ImportRowFormatterTests {
    @Test("Layout 2 · 2.6 MB with a fixed locale")
    func subtitleWithFixedLocale() {
        let fixedLocale = Locale(identifier: "en_US")
        let subtitle = ImportRowFormatter.subtitle(layoutIndex: 2, byteCount: 2_600_000, locale: fixedLocale)
        #expect(subtitle == "Layout 2 · 2.6 MB")
    }

    @Test("66 booths · 3 doors, and singular forms (1 booth · 1 door)")
    func boothsAndDoorsSingularAndPlural() {
        let plural = ImportRowFormatter.boothsAndDoorsText(booths: 66, doors: 3)
        #expect(plural == "66 booths · 3 doors")

        let singular = ImportRowFormatter.boothsAndDoorsText(booths: 1, doors: 1)
        #expect(singular == "1 booth · 1 door")

        let mixed = ImportRowFormatter.boothsAndDoorsText(booths: 1, doors: 2)
        #expect(mixed == "1 booth · 2 doors")
    }

    @Test("Done text has checkmark prefix")
    func doneTextFormat() {
        let done = ImportRowFormatter.doneText(booths: 66, doors: 3)
        #expect(done == "✓ 66 booths · 3 doors")
    }

    @Test("Legend row subtitle is Legend · formattedBytes")
    func legendRowSubtitle() {
        let fixedLocale = Locale(identifier: "en_US")
        let file = ImportFile(
            projectID: UUID(),
            url: URL(fileURLWithPath: "/tmp/legend.pdf"),
            kind: .legend,
            state: .reading(progress: 0.5),
            fileSize: 2_400_000
        )
        let display = ImportRowFormatter.formatLegendRow(file: file, locale: fixedLocale)
        #expect(display.subtitle == "Legend · 2.4 MB")
        #expect(display.title == "legend.pdf")
        #expect(display.isReading)
    }
}

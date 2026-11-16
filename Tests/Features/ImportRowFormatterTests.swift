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

    @Test("Done rows report isDone true and not reading")
    func doneRowsReportIsDone() {
        let display = PlanRowDisplay(
            id: UUID(),
            title: "plan.pdf",
            subtitle: "Layout 1 · 1.0 MB",
            status: .done(text: "✓ 1 booth")
        )
        #expect(display.isDone)
        #expect(!display.isReading)
    }

    @Test("Rows without thumbnail data have no thumbnail")
    func rowWithoutThumbnailDataHasNoThumbnail() {
        let file = ImportFile(
            projectID: UUID(),
            url: URL(fileURLWithPath: "/tmp/plan.pdf"),
            kind: .floorPlan,
            state: .waiting
        )
        let row = ImportRowFormatter.formatRow(file: file, layoutIndex: 1)
        #expect(row.thumbnailData == nil)
    }

    @Test("Reading status carries the pipeline step label")
    func readingStatusCarriesStepLabel() {
        let file = ImportFile(
            projectID: UUID(),
            url: URL(fileURLWithPath: "/tmp/plan.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.5, step: "Detecting booths...")
        )
        let row = ImportRowFormatter.formatRow(file: file, layoutIndex: 1)
        #expect(row.status == .reading(progress: 0.5, step: "Detecting booths..."))
    }
}

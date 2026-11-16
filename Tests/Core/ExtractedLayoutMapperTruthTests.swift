import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import BazaarSimulator

/// Maps what the reader found on each sample plan and scores the layout against the plan's truth file.
/// The scores are the current ones and are compared exactly, so a change to the import, better or worse, fails the row
/// it moves and the row is updated in the same change.
@Suite
struct ExtractedLayoutMapperTruthTests {
    struct PlanCase: Sendable, CustomTestStringConvertible {
        let plan: String
        /// Nil when the plan gives no scale, which is where the reader gives up on it. No sample plan does today.
        let expected: LayoutScore?

        var testDescription: String { plan }
    }

    static let cases = [
        PlanCase(plan: "plan1", expected: LayoutScore(
            sizeRatio: 1.0, truthBooths: 154, boothsFound: 154, boothLabelsRight: 154, extraBooths: 1,
            truthDoors: 4, doorsFound: 4, extraDoors: 2, hallOverlap: 0.76
        )),
        PlanCase(plan: "plan2", expected: LayoutScore(
            sizeRatio: 1.07, truthBooths: 209, boothsFound: 209, boothLabelsRight: 209, extraBooths: 0,
            truthDoors: 4, doorsFound: 4, extraDoors: 0, hallOverlap: 0.78
        )),
        PlanCase(plan: "plan3", expected: LayoutScore(
            sizeRatio: 1.02, truthBooths: 67, boothsFound: 67, boothLabelsRight: 67, extraBooths: 0,
            truthDoors: 1, doorsFound: 0, extraDoors: 0, hallOverlap: 0.92
        )),
        PlanCase(plan: "plan5", expected: LayoutScore(
            sizeRatio: 0.87, truthBooths: 306, boothsFound: 272, boothLabelsRight: 262, extraBooths: 0,
            truthDoors: 4, doorsFound: 0, extraDoors: 3, hallOverlap: 0.56
        )),
        PlanCase(plan: "plan6", expected: LayoutScore(
            sizeRatio: 1.04, truthBooths: 289, boothsFound: 282, boothLabelsRight: 281, extraBooths: 8,
            truthDoors: 2, doorsFound: 2, extraDoors: 0, hallOverlap: 0.72
        ))
    ]

    @Test("A sample plan maps to its recorded score against the truth layout", arguments: cases)
    func score(_ planCase: PlanCase) throws {
        let score = try Self.score(of: planCase.plan)

        #expect(score == planCase.expected)
    }

    private static func score(of plan: String) throws -> LayoutScore? {
        let detected = try TestFixtureLoader.load(DetectedPlan.self, from: "\(plan)-detected")
        let truthFile = try MockDataStore.load(BazaarLayoutDTO.self, from: "\(plan)-truth")
        let truth = MockLayoutMapper.layout(from: truthFile, legend: Legend())
        let frame = try MockDataStore.load(MockPlanFrame.self, from: "\(plan)-frame")
        let readScale = detected.printedPixelsPerMetre ?? ExtractedLayoutMapper.assumedPixelsPerMetre(for: detected)
        guard let scale = readScale else { return nil }

        let layout = ExtractedLayoutMapper.layout(from: detected, legend: Legend(), pixelsPerMetre: scale, name: plan)

        return LayoutScore(
            of: frame.inTruthMetres(layout, readFrom: detected, pixelsPerMetre: scale),
            against: truth,
            sizeRatio: frame.pixelsPerMetre / scale
        )
    }

    /// Reads every sample plan with the real extractor and rewrites the fixtures in Tests/Fixtures, for when the
    /// extractor or the reader changes. The extractor is too slow unoptimised and the sandboxed app cannot write to
    /// the source folder, so run it as `TEST_RUNNER_RECORD_PLAN_FIXTURES=1 xcodebuild test -scheme BazaarSimulator
    /// -configuration Release ENABLE_TESTABILITY=YES ENABLE_APP_SANDBOX=NO
    /// -only-testing:BazaarSimulatorTests/ExtractedLayoutMapperTruthTests`.
    @Test(
        "Record what the reader finds on every sample plan",
        .enabled(if: ProcessInfo.processInfo.environment["RECORD_PLAN_FIXTURES"] != nil)
    )
    func record() async throws {
        let fixtures = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures")
        let scratch = FileManager.default.temporaryDirectory.appending(path: "plan-fixtures")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        for plan in Self.cases.map(\.plan) {
            let detected = try await ExtractorFloorPlanReader().detectPlan(
                try Self.importedPage("\(plan)-layout", in: scratch),
                legendPage: try Self.importedPage("\(plan)-legend", in: scratch)
            )
            try encoder.encode(detected).write(to: fixtures.appending(path: "\(plan)-detected.json"))
        }
    }

    /// A bundled plan image as the app would see it: wrapped in a one page PDF and drawn by the PDF importer.
    private static func importedPage(_ name: String, in folder: URL) throws -> CGImage {
        let imageURL = try #require(Bundle.main.url(forResource: name, withExtension: "png"))
        let source = try #require(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pageBox = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let pdfURL = folder.appending(path: "\(name).pdf")
        let context = try #require(CGContext(pdfURL as CFURL, mediaBox: &pageBox, nil))
        context.beginPDFPage(nil)
        context.draw(image, in: pageBox)
        context.endPDFPage()
        context.closePDF()
        return try PDFImportService().renderFirstPage(of: pdfURL)
    }
}

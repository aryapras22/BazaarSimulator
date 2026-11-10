import CoreGraphics
import Foundation
import Testing
@testable import BazaarSimulator

private struct StubPDF: PDFImporting {
    func renderFirstPage(of url: URL) throws -> CGImage {
        CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!.makeImage()!
    }
}

private actor ReadLog {
    private(set) var names: [String] = []
    func record(_ name: String) { names.append(name) }
}

private struct StubReader: FloorPlanReading {
    let log: ReadLog
    var failingPlan: String?

    func readLegend(_ page: CGImage) async throws -> Legend {
        await log.record("legend")
        return Legend(entries: [LegendEntry(name: "Booth A", color: LegendColor(red: 1, green: 0, blue: 0))])
    }

    func readPlan(
        _ page: CGImage, legendPage: CGImage, legend: Legend, name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExtractedLayout {
        await log.record(name)
        if name == failingPlan { throw FloorPlanReadingError.noBooths }
        return ExtractedLayout(layout: Layout(name: name, sizeM: .init(10, 10)))
    }
}

@Suite("ImportQueueTests")
@MainActor
struct ImportQueueTests {
    private func settled(_ queue: ImportQueue, projectID: UUID) async {
        func isBusy(_ file: ImportFile) -> Bool {
            if case .done = file.state { return false }
            if case .failed = file.state { return false }
            return file.state != .cancelled
        }
        for _ in 0..<200 where queue.files(for: projectID).contains(where: isBusy) {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("A legend added after the plans is still read first")
    func legendsFirst() async {
        let log = ReadLog()
        let queue = ImportQueue(pdf: StubPDF(), reader: StubReader(log: log))
        let projectID = UUID()

        queue.add(urls: [URL(fileURLWithPath: "/tmp/one.pdf")], kind: .floorPlan, projectID: projectID)
        queue.add(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")], kind: .legend, projectID: projectID)
        await settled(queue, projectID: projectID)

        #expect(await log.names == ["legend", "one"])
    }

    @Test("A failed plan does not stop the next one")
    func failureIsolated() async {
        let queue = ImportQueue(pdf: StubPDF(), reader: StubReader(log: ReadLog(), failingPlan: "bad"))
        let projectID = UUID()
        queue.add(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")], kind: .legend, projectID: projectID)
        queue.add(
            urls: [URL(fileURLWithPath: "/tmp/bad.pdf"), URL(fileURLWithPath: "/tmp/good.pdf")],
            kind: .floorPlan, projectID: projectID
        )

        await settled(queue, projectID: projectID)

        let plans = queue.files(for: projectID).filter { $0.kind == .floorPlan }
        #expect(plans[0].state == .failed(message: "Couldn't read this plan"))
        #expect(plans[1].state == .done(booths: 0, doors: 0))
        #expect(queue.extractedLayout(for: plans[1].id)?.name == "good")
    }

    @Test("Cancel marks waiting files cancelled")
    func cancelMarksWaiting() {
        let queue = ImportQueue(pdf: StubPDF(), reader: StubReader(log: ReadLog()))
        let projectID = UUID()
        queue.add(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")], kind: .legend, projectID: projectID)

        queue.cancel(projectID: projectID)

        #expect(queue.files(for: projectID).allSatisfy { $0.state == .cancelled })
    }
}

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
    var events: [PlanReadingEvent] = []

    func readLegend(_ page: CGImage) async throws -> Legend {
        await log.record("legend")
        return Legend(entries: [LegendEntry(name: "Booth A", color: LegendColor(red: 1, green: 0, blue: 0))])
    }

    func readPlan(
        _ page: CGImage, legendPage: CGImage, legend: Legend, name: String,
        onEvent: @escaping @MainActor @Sendable (PlanReadingEvent) -> Void
    ) async throws -> ExtractedLayout {
        await log.record(name)
        for event in events { await onEvent(event) }
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

    private func readPlan(
        named name: String,
        reader: StubReader,
        logLimit: Int = 2000,
        projectID: UUID = UUID()
    ) async -> (queue: ImportQueue, projectID: UUID) {
        let queue = ImportQueue(pdf: StubPDF(), reader: reader, logLimit: logLimit)
        queue.add(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")], kind: .legend, projectID: projectID)
        await settled(queue, projectID: projectID)
        queue.add(urls: [URL(fileURLWithPath: "/tmp/\(name).pdf")], kind: .floorPlan, projectID: projectID)
        await settled(queue, projectID: projectID)
        return (queue, projectID)
    }

    @Test("The log follows a plan from picked to done in step order")
    func logFollowsPlan() async {
        let reader = StubReader(log: ReadLog(), events: [.note("Plan read: 3 items")])

        let (queue, projectID) = await readPlan(named: "one", reader: reader)

        let messages = queue.logEntries(for: projectID).filter { $0.fileName == "one.pdf" }.map(\.message)
        #expect(messages.first?.hasPrefix("Picked") == true)
        #expect(Array(messages.dropFirst()) == [
            "Started reading",
            "Rendered one.pdf, 1 x 1 px",
            "Matched legend.pdf",
            "Rendered legend.pdf, 1 x 1 px",
            "Reading plan",
            "Plan read: 3 items",
            "Done: 0 booths, 0 doors"
        ])
    }

    @Test("A failed read logs the error text as a failure")
    func failureLogged() async {
        let (queue, projectID) = await readPlan(
            named: "bad",
            reader: StubReader(log: ReadLog(), failingPlan: "bad")
        )

        let last = queue.logEntries(for: projectID).last
        #expect(last?.message == "Failed: noBooths")
        #expect(last?.severity == .failure)
    }

    @Test("Extractor progress is logged once per quarter")
    func progressLoggedPerQuarter() async {
        let progress: [PlanReadingEvent] = [.progress(0.1), .progress(0.3), .progress(0.4), .progress(0.8)]

        let (queue, projectID) = await readPlan(named: "one", reader: StubReader(log: ReadLog(), events: progress))

        let lines = queue.logEntries(for: projectID).map(\.message).filter { $0.hasPrefix("Extractor") }
        #expect(lines == ["Extractor at 25%", "Extractor at 75%"])
    }

    @Test("The oldest lines are dropped past the limit")
    func logIsCapped() async {
        let (queue, projectID) = await readPlan(named: "one", reader: StubReader(log: ReadLog()), logLimit: 2)

        let messages = queue.logEntries(for: projectID).map(\.message)
        #expect(messages == ["Reading plan", "Done: 0 booths, 0 doors"])
    }

    @Test("Each project sees only its own log, and removing a project clears it")
    func logPerProject() async {
        let queue = ImportQueue(pdf: StubPDF(), reader: StubReader(log: ReadLog()))
        let first = UUID()
        let second = UUID()
        queue.add(urls: [URL(fileURLWithPath: "/tmp/a.pdf")], kind: .legend, projectID: first)
        queue.add(urls: [URL(fileURLWithPath: "/tmp/b.pdf")], kind: .legend, projectID: second)

        queue.removeAll(projectID: first)

        #expect(queue.logEntries(for: first).isEmpty)
        #expect(queue.logEntries(for: second).map(\.fileName).allSatisfy { $0 == "b.pdf" })
        #expect(!queue.logEntries(for: second).isEmpty)
    }
}

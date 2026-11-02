import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ScriptedImportQueueTests")
struct ScriptedImportQueueTests {
    @Test("Async fake reads one file at a time")
    @MainActor
    func asyncFakeReadsOneFileAtATime() async {
        let queue = ScriptedImportQueue(isSynchronous: false)
        let projectID = UUID()

        queue.add(
            urls: [
                URL(fileURLWithPath: "/tmp/plan1.pdf"),
                URL(fileURLWithPath: "/tmp/plan2.pdf")
            ],
            kind: .floorPlan,
            projectID: projectID
        )

        await Task.yield()

        let files = queue.files(for: projectID)
        #expect(files.count == 2)
        if case .reading = files[0].state {
            // First file is reading
        } else if case .waiting = files[0].state {
            // Or waiting if worker hasn't started yet
        } else {
            Issue.record("Expected first file to be reading or waiting")
        }
        #expect(files[1].state == .waiting)
    }

    @Test("A plan whose mock layout cannot load fails")
    @MainActor
    func planWhoseMockLayoutCannotLoadFails() {
        let queue = ScriptedImportQueue(isSynchronous: true)
        queue.mockLayoutFileNames = ["missing-mock-layout"]
        let projectID = UUID()

        queue.add(
            urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")],
            kind: .floorPlan,
            projectID: projectID
        )

        let file = queue.files(for: projectID).first
        #expect(file?.state == .failed(message: "Couldn't load the mock layout"))
        if let fileID = file?.id {
            #expect(queue.extractedLayout(for: fileID) == nil)
        }
    }
}

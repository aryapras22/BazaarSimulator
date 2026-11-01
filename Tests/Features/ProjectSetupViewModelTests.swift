import Foundation
import Testing
@testable import BazaarSimulator

@Suite("ProjectSetupViewModelTests")
struct ProjectSetupViewModelTests {
    @Test("Floor plans are refused until a legend is read")
    @MainActor
    func floorPlansRefusedUntilLegendIsRead() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        #expect(!viewModel.hasLegend)
        #expect(!viewModel.isFloorPlanZoneEnabled)

        let planURL = URL(fileURLWithPath: "/tmp/layout1.pdf")
        viewModel.addFloorPlanFiles(urls: [planURL])

        #expect(viewModel.floorPlanFiles.isEmpty)
        #expect(viewModel.statusText.contains("Add a legend"))
    }

    @Test("The 7th floor plan is refused, and the floor plan zone disables at 6")
    @MainActor
    func maxSixFloorPlansAllowed() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(viewModel.hasLegend)

        let sixPlans = (1...6).map { URL(fileURLWithPath: "/tmp/layout\($0).pdf") }
        viewModel.addFloorPlanFiles(urls: sixPlans)

        #expect(viewModel.floorPlanFiles.count == 6)
        #expect(!viewModel.isFloorPlanZoneEnabled)

        let seventhPlan = URL(fileURLWithPath: "/tmp/layout7.pdf")
        viewModel.addFloorPlanFiles(urls: [seventhPlan])

        #expect(viewModel.floorPlanFiles.count == 6)
        #expect(viewModel.statusText.contains("At most 6"))
    }

    @Test("addFloorPlanFiles accepts files up to 6 and drops the rest with a message")
    @MainActor
    func addFloorPlanFilesAcceptsUpToCap() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])

        let fourPlans = (1...4).map { URL(fileURLWithPath: "/tmp/layout\($0).pdf") }
        viewModel.addFloorPlanFiles(urls: fourPlans)
        #expect(viewModel.floorPlanFiles.count == 4)

        let threeMorePlans = (5...7).map { URL(fileURLWithPath: "/tmp/layout\($0).pdf") }
        viewModel.addFloorPlanFiles(urls: threeMorePlans)

        #expect(viewModel.floorPlanFiles.count == 6)
        #expect(viewModel.statusText.contains("At most 6"))
    }

    @Test("Non-PDF files are refused with a message")
    @MainActor
    func nonPDFFilesRefusedWithMessage() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        let nonPDF = URL(fileURLWithPath: "/tmp/image.png")
        viewModel.addLegendFiles(urls: [nonPDF])

        #expect(viewModel.legendEntries.isEmpty)
        #expect(viewModel.statusText == "Only PDF files are accepted")
    }

    @Test("Removing a legend entry removes it from the draft and updates the count")
    @MainActor
    func removingLegendEntryUpdatesDraftAndCount() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(viewModel.legendEntries.count == 3)

        let entryToRemove = viewModel.legendEntries[0]
        viewModel.removeLegendEntry(id: entryToRemove.id)

        #expect(viewModel.legendEntries.count == 2)
        #expect(!viewModel.legendEntries.contains(where: { $0.id == entryToRemove.id }))
    }

    @Test("Legend entries appear once async legend read finishes")
    @MainActor
    func legendEntriesAppearOnceAsyncReadFinishes() async {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(viewModel.legendEntries.isEmpty)

        try? await Task.sleep(nanoseconds: 500_000_000)

        #expect(!viewModel.legendEntries.isEmpty)
        #expect(viewModel.hasLegend)
    }

    @Test("The status text names the first plan still reading")
    @MainActor
    func statusTextNamesFirstPlanStillReading() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        queue.insert(ImportFile(
            projectID: project.id,
            url: URL(fileURLWithPath: "/tmp/legend.pdf"),
            kind: .legend,
            state: .done(booths: 0, doors: 0)
        ))

        let plan1 = URL(fileURLWithPath: "/tmp/plan1.pdf")
        let plan2 = URL(fileURLWithPath: "/tmp/plan2.pdf")
        queue.insert(ImportFile(projectID: project.id, url: plan1, kind: .floorPlan, state: .done(booths: 10, doors: 2)))
        queue.insert(ImportFile(projectID: project.id, url: plan2, kind: .floorPlan, state: .reading(progress: 0.5)))

        #expect(viewModel.statusText == "Waiting for Layout 2 to finish reading...")
    }

    @Test("Continue needs a name, at least one plan, and every file done")
    @MainActor
    func continueConditions() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        #expect(!viewModel.isContinueEnabled)

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(!viewModel.isContinueEnabled)

        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        #expect(viewModel.isContinueEnabled)

        viewModel.projectName = "  "
        #expect(!viewModel.isContinueEnabled)
        #expect(viewModel.statusText == "Name the project to continue")

        viewModel.projectName = "Bazaar 1"
        #expect(viewModel.isContinueEnabled)
        #expect(viewModel.statusText == "Ready to continue")
    }

    @Test("Cancel marks waiting and reading files as cancelled")
    @MainActor
    func cancelMarksFilesCancelled() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        let file = ImportFile(
            projectID: project.id,
            url: URL(fileURLWithPath: "/tmp/plan.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.2)
        )
        queue.insert(file)

        #expect(viewModel.isCancelEnabled)

        viewModel.cancel()

        #expect(queue.files.first?.state == .cancelled)
        #expect(!viewModel.isCancelEnabled)
    }

    @Test("Two view models against the same queue see only their own files")
    @MainActor
    func viewModelsIsolateFilesByProject() {
        let session = ProjectSession()
        let project1 = session.createProject(named: "Bazaar 1")
        let project2 = session.createProject(named: "Bazaar 2")
        let queue = ScriptedImportQueue(isSynchronous: true)

        let vm1 = ProjectSetupViewModel(
            projectID: project1.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )
        let vm2 = ProjectSetupViewModel(
            projectID: project2.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        vm1.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        vm1.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])

        #expect(vm1.floorPlanFiles.count == 1)
        #expect(vm1.hasLegend)

        #expect(vm2.floorPlanFiles.isEmpty)
        #expect(!vm2.hasLegend)
    }

    @Test("Cancel cancels only the active project's files")
    @MainActor
    func cancelCancelsOnlyActiveProjectFiles() {
        let session = ProjectSession()
        let project1 = session.createProject(named: "Bazaar 1")
        let project2 = session.createProject(named: "Bazaar 2")
        let queue = ScriptedImportQueue(isSynchronous: false)

        let vm1 = ProjectSetupViewModel(
            projectID: project1.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )
        _ = ProjectSetupViewModel(
            projectID: project2.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        let file1 = ImportFile(
            projectID: project1.id,
            url: URL(fileURLWithPath: "/tmp/p1.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.2)
        )
        let file2 = ImportFile(
            projectID: project2.id,
            url: URL(fileURLWithPath: "/tmp/p2.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.2)
        )
        queue.insert(file1)
        queue.insert(file2)

        vm1.cancel()

        #expect(queue.files(for: project1.id).first?.state == .cancelled)
        if case .reading = queue.files(for: project2.id).first?.state {
            // Success: project2's file was not cancelled
        } else {
            Issue.record("Expected project2 file to remain reading")
        }
    }

    @Test("Continue writes the draft to ProjectSession and invokes onContinue")
    @MainActor
    func continueWritesDraftToSession() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        var continuedProjectID: UUID?
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { continuedProjectID = $0 }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        viewModel.projectName = "Super Bazaar"

        viewModel.continueToReview()

        #expect(session.draft(for: project.id) != nil)
        #expect(session.draft(for: project.id)?.name == "Super Bazaar")
        #expect(session.draft(for: project.id)?.legend.entries.count == 3)
        #expect(session.draft(for: project.id)?.layouts.count == 1)
        #expect(continuedProjectID == project.id)
    }

    @Test("Dropping an async legend creates pendingLegendRows and sets status")
    @MainActor
    func asyncLegendCreatesPendingRowAndStatus() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])

        #expect(viewModel.pendingLegendRows.count == 1)
        #expect(viewModel.statusText == "Reading the legend...")
    }

    @Test("Failed legend file can be retried or deleted")
    @MainActor
    func failedLegendCanBeRetriedOrDeleted() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        queue.failFile(named: "bad_legend.pdf")

        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/bad_legend.pdf")])

        #expect(viewModel.pendingLegendRows.count == 1)
        guard let row = viewModel.pendingLegendRows.first else {
            Issue.record("Expected pending row")
            return
        }
        if case .failed = row.status {
            // Success
        } else {
            Issue.record("Expected failed row status")
        }

        viewModel.deleteLegendFile(id: row.id)
        #expect(viewModel.pendingLegendRows.isEmpty)
        #expect(viewModel.legendFiles.isEmpty)
    }

    @Test("Continue refuses to navigate if extracted layout is missing")
    @MainActor
    func continueRefusesWhenLayoutMissing() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        var continued = false
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in continued = true }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        let planFile = ImportFile(
            projectID: project.id,
            url: URL(fileURLWithPath: "/tmp/plan1.pdf"),
            kind: .floorPlan,
            state: .done(booths: 10, doors: 2)
        )
        queue.insert(planFile)
        #expect(queue.extractedLayout(for: planFile.id) == nil)

        viewModel.continueToReview()

        #expect(!continued)
        #expect(viewModel.bannerMessage == "Some floor plans could not be read")
        #expect(session.draft(for: project.id) == nil)
    }
}

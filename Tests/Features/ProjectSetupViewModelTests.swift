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
        #expect(viewModel.statusText == "Only 6 floor plans allowed")
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
        #expect(viewModel.statusText == "Only 6 floor plans allowed. Added 2 of 3.")
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
        queue.insert(ImportFile(
            projectID: project.id,
            url: plan1,
            kind: .floorPlan,
            state: .done(booths: 10, doors: 2)
        ))
        queue.insert(ImportFile(
            projectID: project.id,
            url: plan2,
            kind: .floorPlan,
            state: .reading(progress: 0.5)
        ))

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
}

extension ProjectSetupViewModelTests {
    @Test("Continue is disabled when every legend entry is removed")
    @MainActor
    func continueDisabledWhenAllLegendEntriesRemoved() {
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
        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        #expect(viewModel.isContinueEnabled)

        for entry in viewModel.legendEntries {
            viewModel.removeLegendEntry(id: entry.id)
        }

        #expect(!viewModel.isContinueEnabled)
        #expect(viewModel.statusText == "Keep at least one legend category to continue")
    }

    @Test("Continue saves only the remaining legend entries")
    @MainActor
    func continueSavesRemainingLegendEntries() {
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
        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        guard let firstID = viewModel.legendEntries.first?.id else {
            Issue.record("Expected legend entries")
            return
        }
        viewModel.removeLegendEntry(id: firstID)

        viewModel.continueToReview()

        #expect(session.draft(for: project.id)?.legend.entries.count == 2)
    }

    @Test("Refused files show an error status")
    @MainActor
    func refusedFilesShowErrorStatus() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/image.png")])
        #expect(viewModel.isStatusError)

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(!viewModel.isStatusError)
    }

    @Test("Continue saves a trimmed name")
    @MainActor
    func continueSavesTrimmedName() {
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
        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        viewModel.projectName = "  Night Market  "

        viewModel.continueToReview()

        #expect(session.draft(for: project.id)?.name == "Night Market")
    }
}

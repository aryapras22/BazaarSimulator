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
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
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
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
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

    @Test("Non-PDF files are refused with a message")
    @MainActor
    func nonPDFFilesRefusedWithMessage() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
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
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(viewModel.legendEntries.count == 3)

        let entryToRemove = viewModel.legendEntries[0]
        viewModel.removeLegendEntry(id: entryToRemove.id)

        #expect(viewModel.legendEntries.count == 2)
        #expect(!viewModel.legendEntries.contains(where: { $0.id == entryToRemove.id }))
    }

    @Test("The status text names the first plan still reading")
    @MainActor
    func statusTextNamesFirstPlanStillReading() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])

        let plan1 = URL(fileURLWithPath: "/tmp/plan1.pdf")
        let plan2 = URL(fileURLWithPath: "/tmp/plan2.pdf")
        queue.files.append(ImportFile(url: plan1, kind: .floorPlan, state: .done(booths: 10, doors: 2)))
        queue.files.append(ImportFile(url: plan2, kind: .floorPlan, state: .reading(progress: 0.5)))

        #expect(viewModel.statusText == "Waiting for Layout 2 to finish reading...")
    }

    @Test("Continue needs a name, at least one plan, and every file done")
    @MainActor
    func continueConditions() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
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
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
        )

        let file = ImportFile(
            url: URL(fileURLWithPath: "/tmp/plan.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.2)
        )
        queue.files.append(file)

        #expect(viewModel.isCancelEnabled)

        viewModel.cancel()

        #expect(queue.files[0].state == .cancelled)
        #expect(!viewModel.isCancelEnabled)
    }

    @Test("Continue writes the draft to ProjectSession")
    @MainActor
    func continueWritesDraftToSession() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let router = AppRouter()
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            router: router
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        viewModel.addFloorPlanFiles(urls: [URL(fileURLWithPath: "/tmp/plan1.pdf")])
        viewModel.projectName = "Super Bazaar"

        viewModel.continueToReview()

        #expect(session.draft(for: project.id) != nil)
        #expect(session.draft(for: project.id)?.name == "Super Bazaar")
        #expect(session.draft(for: project.id)?.legend.entries.count == 3)
        #expect(session.draft(for: project.id)?.layouts.count == 1)
        #expect(router.destination == .reviewPlaceholder)
    }
}

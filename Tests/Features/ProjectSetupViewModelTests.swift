import Foundation
import simd
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

    @Test("More than 6 floor plans are accepted and the floor plan zone stays enabled")
    @MainActor
    func acceptsMoreThanSixFloorPlans() {
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
        #expect(viewModel.isFloorPlanZoneEnabled)

        let morePlans = (7...9).map { URL(fileURLWithPath: "/tmp/layout\($0).pdf") }
        viewModel.addFloorPlanFiles(urls: morePlans)

        #expect(viewModel.floorPlanFiles.count == 9)
        #expect(viewModel.isFloorPlanZoneEnabled)
        #expect(!viewModel.isStatusError)
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

    @Test("A legend entry keeps the booth type the user picks, and the draft carries it")
    @MainActor
    func legendEntryKeepsPickedCategory() throws {
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
        let entry = try #require(viewModel.legendEntries.first { $0.type == .fnb })

        viewModel.setLegendEntryType(id: entry.id, to: .goods)
        viewModel.continueToReview()

        #expect(viewModel.legendEntries.first { $0.id == entry.id }?.type == .goods)
        #expect(session.draft(for: project.id)?.legend.entries.first { $0.id == entry.id }?.type == .goods)
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

        for _ in 0..<100 where viewModel.legendEntries.isEmpty {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

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

        #expect(viewModel.statusText == "Waiting for all layouts to finish reading...")
    }

    @Test("The status text includes the pipeline stage and percentage when reading a layout")
    @MainActor
    func statusTextIncludesPipelineStage() {
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
        queue.insert(ImportFile(
            projectID: project.id,
            url: URL(fileURLWithPath: "/tmp/plan1.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.35, step: "Detecting booths...")
        ))

        #expect(viewModel.statusText == "Layout 1: Detecting booths... (35%)")
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

    @Test("Continue after Back keeps editor changes")
    @MainActor
    func continueAfterBackKeepsEditorChanges() throws {
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
        viewModel.continueToReview()

        var layout = try #require(session.draft(for: project.id)?.layouts.first)
        let boothIndex = try #require(layout.objects.firstIndex { $0.kind == .booth })
        let boothID = layout.objects[boothIndex].id
        let newCenter = SIMD2<Double>(42, 42)
        layout.objects[boothIndex].placement.center = newCenter
        session.updateLayout(layout, in: project.id)

        viewModel.continueToReview()

        let updatedLayout = try #require(session.draft(for: project.id)?.layouts.first)
        let updatedBooth = try #require(updatedLayout.objects.first { $0.id == boothID })
        #expect(updatedBooth.placement.center == newCenter)
    }

    @Test("Preview and row summaries reflect layout edits saved in ProjectSession")
    @MainActor
    func previewAndPlanRowsReflectSessionEdits() throws {
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
        let file = try #require(viewModel.floorPlanFiles.first)
        viewModel.continueToReview()

        var editedLayout = try #require(session.layout(id: file.id, in: project.id))
        let initialBooths = editedLayout.objects.filter { $0.kind == .booth }.count
        let initialDoors = editedLayout.objects.filter { $0.kind == .door }.count

        let addedBooth = LayoutObject(
            kind: .booth,
            label: "B-New",
            placement: Placement(center: SIMD2<Double>(12, 12), sizeM: SIMD2<Double>(2, 2))
        )
        let addedDoor = LayoutObject(
            kind: .door,
            label: "D-New",
            placement: Placement(center: SIMD2<Double>(1, 0), sizeM: SIMD2<Double>(2, 0.3))
        )
        editedLayout.objects.append(contentsOf: [addedBooth, addedDoor])
        session.updateLayout(editedLayout, in: project.id)

        let preview = try #require(viewModel.previewLayout(fileID: file.id))
        #expect(preview.objects.contains { $0.id == addedBooth.id })
        #expect(preview.objects.contains { $0.id == addedDoor.id })

        let row = try #require(viewModel.planRows.first { $0.id == file.id })
        let expectedStatus = PlanRowDisplay.Status.done(
            text: ImportRowFormatter.doneText(booths: initialBooths + 1, doors: initialDoors + 1)
        )
        #expect(row.status == expectedStatus)
    }
}

@Suite("UploadPageStatesTests")
@MainActor
struct UploadPageStatesTests {
    private func model() -> (ProjectSetupViewModel, ScriptedImportQueue, ProjectSummary) {
        let queue = ScriptedImportQueue(isSynchronous: true)
        let session = ProjectSession()
        let project = session.createProject(named: "Basha Vol. 1")
        let viewModel = ProjectSetupViewModel(
            projectID: project.id, session: session, importQueue: queue, onContinue: { _ in }
        )
        return (viewModel, queue, project)
    }

    @Test("A file that is not a PDF is named so the page can say it is unsupported")
    func unsupportedFileIsNamed() {
        let (viewModel, _, _) = model()

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/Plan_Legend.dwg")])
        #expect(viewModel.unsupportedFileName == "Plan_Legend.dwg")

        viewModel.clearUnsupportedFile()
        #expect(viewModel.unsupportedFileName == nil)
    }

    @Test("Legend required shows only when plans are listed and there is no legend")
    func legendRequired() {
        let (viewModel, queue, project) = model()
        #expect(!viewModel.showsLegendRequired)

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        queue.insert(ImportFile(
            projectID: project.id, url: URL(fileURLWithPath: "/tmp/plan.pdf"), kind: .floorPlan,
            state: .done(booths: 66, doors: 3), fileSize: 1000
        ))
        #expect(!viewModel.showsLegendRequired)

        viewModel.deleteAllLegends()
        #expect(viewModel.showsLegendRequired)
        #expect(!viewModel.isContinueEnabled)
    }

    @Test("A plan that is still being read cannot be previewed, and one that was read can")
    func previewNeedsAReadPlan() {
        let (viewModel, queue, project) = model()
        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        let reading = ImportFile(
            projectID: project.id, url: URL(fileURLWithPath: "/tmp/a.pdf"), kind: .floorPlan,
            state: .reading(progress: 0.5), fileSize: 1000
        )
        queue.insert(reading)

        #expect(viewModel.previewLayout(fileID: reading.id) == nil)
    }

    @Test("The categories offered are Foods, Goods and Others")
    func categories() {
        #expect(BoothType.allCases.map(\.displayName) == ["Foods", "Goods"])
    }
}

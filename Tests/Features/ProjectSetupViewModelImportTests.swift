import Foundation
import simd
import SwiftUI
import Testing
@testable import BazaarSimulator

extension ProjectSetupViewModelTests {
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

    @Test("Delete all legends removes this project's legend files and keeps its plans")
    @MainActor
    func deleteAllLegendsKeepsPlans() {
        let session = ProjectSession()
        let project = session.createProject(named: "Untitled")
        let other = session.createProject(named: "Untitled 2")
        let queue = ScriptedImportQueue(isSynchronous: false)
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )
        let url = URL(fileURLWithPath: "/tmp/file.pdf")
        queue.insert(ImportFile(projectID: project.id, url: url, kind: .legend, state: .waiting))
        queue.insert(ImportFile(projectID: project.id, url: url, kind: .legend, state: .waiting))
        queue.insert(ImportFile(projectID: project.id, url: url, kind: .floorPlan, state: .waiting))
        queue.insert(ImportFile(projectID: other.id, url: url, kind: .legend, state: .waiting))

        viewModel.deleteAllLegends()

        #expect(viewModel.legendFiles.isEmpty)
        #expect(viewModel.floorPlanFiles.count == 1)
        #expect(queue.files(for: other.id).count == 1)
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
        if case .failed(let message) = row.status {
            #expect(message == "Couldn't read this legend")
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
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
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

        #expect(viewModel.bannerMessage == "Some floor plans could not be read")
        #expect(session.draft(for: project.id) == nil)
    }

    @Test("Removed entries stay removed after a second legend")
    @MainActor
    func removedEntriesStayRemovedAfterSecondLegend() {
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
        guard let removedID = viewModel.legendEntries.first?.id else {
            Issue.record("Expected legend entries")
            return
        }
        viewModel.removeLegendEntry(id: removedID)

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend2.pdf")])

        #expect(viewModel.legendEntries.count == 5)
        #expect(!viewModel.legendEntries.contains(where: { $0.id == removedID }))
    }

    @Test("Removing the only legend file clears the legend")
    @MainActor
    func removingOnlyLegendFileClearsLegend() {
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

        queue.remove(fileID: queue.files[0].id)

        #expect(!viewModel.hasLegend)
        #expect(viewModel.legendEntries.isEmpty)
    }

    @Test("Retrying a failed legend replaces its result")
    @MainActor
    func retryingFailedLegendReplacesResult() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        queue.failFile(named: "legend.pdf")

        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        #expect(viewModel.legendEntries.isEmpty)
        guard let failedFileID = viewModel.pendingLegendRows.first?.id else {
            Issue.record("Expected pending legend row")
            return
        }

        queue.failingFileNames.removeAll()
        viewModel.retryLegendFile(id: failedFileID)

        #expect(viewModel.legendEntries.count == 3)
        #expect(viewModel.pendingLegendRows.isEmpty)
    }

    @Test("editLayout writes the draft and selects the requested layout")
    @MainActor
    func editLayoutWritesDraftAndSelectsLayout() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        var editedProjectID: UUID?
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in },
            onEdit: { editedProjectID = $0 }
        )

        viewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        viewModel.addFloorPlanFiles(urls: [
            URL(fileURLWithPath: "/tmp/plan1.pdf"),
            URL(fileURLWithPath: "/tmp/plan2.pdf")
        ])

        let targetFile = viewModel.floorPlanFiles[1]
        viewModel.editLayout(fileID: targetFile.id)

        let draft = try #require(session.draft(for: project.id))
        #expect(draft.layouts.count == 2)
        #expect(session.activeLayoutID(for: project.id) == targetFile.id)
        #expect(editedProjectID == project.id)
    }

    @Test("editLayout is ignored when the layout file is still reading")
    @MainActor
    func editLayoutIgnoredWhileReading() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: false)
        var editedProjectID: UUID?
        let viewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in },
            onEdit: { editedProjectID = $0 }
        )

        let readingID = UUID()
        queue.insert(ImportFile(
            projectID: project.id,
            id: readingID,
            url: URL(fileURLWithPath: "/tmp/plan1.pdf"),
            kind: .floorPlan,
            state: .reading(progress: 0.5)
        ))

        viewModel.editLayout(fileID: readingID)

        #expect(session.draft(for: project.id) == nil)
        #expect(session.activeLayoutID(for: project.id) == nil)
        #expect(editedProjectID == nil)
    }

    @Test("editLayout displays the imported floor plan's real name in the editor header")
    @MainActor
    func editLayoutDisplaysRealLayoutNameInEditorHeader() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let queue = ScriptedImportQueue(isSynchronous: true)
        let setupViewModel = ProjectSetupViewModel(
            projectID: project.id,
            session: session,
            importQueue: queue,
            onContinue: { _ in },
            onEdit: { _ in }
        )

        setupViewModel.addLegendFiles(urls: [URL(fileURLWithPath: "/tmp/legend.pdf")])
        setupViewModel.addFloorPlanFiles(urls: [
            URL(fileURLWithPath: "/tmp/plan1.pdf"),
            URL(fileURLWithPath: "/tmp/plan2.pdf")
        ])

        let targetFile = setupViewModel.floorPlanFiles[1]
        setupViewModel.editLayout(fileID: targetFile.id)

        let editorViewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        let headerTexts = EditorHeaderTextExtractor.texts(in: EditorHeaderBar(viewModel: editorViewModel).body)

        #expect(editorViewModel.activeLayout?.name == "plan2")
        #expect(headerTexts.contains("plan2"))
        #expect(!headerTexts.contains("Layout 1"))
        #expect(!headerTexts.contains("Layout 2"))
    }

    @Test("Editor header trims whitespace around the active layout name")
    @MainActor
    func editorHeaderTrimsActiveLayoutName() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let layout = Layout(name: "  Main Hall  ", sizeM: SIMD2<Double>(20, 20))
        session.setDraft(ProjectDraft(name: "Bazaar 1", layouts: [layout]), for: project.id)

        let editorViewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        let headerTexts = EditorHeaderTextExtractor.texts(in: EditorHeaderBar(viewModel: editorViewModel).body)

        #expect(headerTexts.contains("Main Hall"))
        #expect(!headerTexts.contains("  Main Hall  "))
        #expect(!headerTexts.contains("Layout 1"))
    }

    @Test("Editor header falls back to Layout N when the layout name is empty or whitespace")
    @MainActor
    func editorHeaderFallsBackWhenLayoutNameIsEmpty() {
        let session = ProjectSession()
        let project = session.createProject(named: "Bazaar 1")
        let first = Layout(name: "", sizeM: SIMD2<Double>(20, 20))
        let second = Layout(name: "   \n ", sizeM: SIMD2<Double>(20, 20))
        session.setDraft(ProjectDraft(name: "Bazaar 1", layouts: [first, second]), for: project.id)

        let editorViewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        let firstTexts = EditorHeaderTextExtractor.texts(in: EditorHeaderBar(viewModel: editorViewModel).body)
        #expect(firstTexts.contains("Layout 1"))

        editorViewModel.selectLayout(second.id)
        let secondTexts = EditorHeaderTextExtractor.texts(in: EditorHeaderBar(viewModel: editorViewModel).body)
        #expect(secondTexts.contains("Layout 2"))
    }
}

private enum EditorHeaderTextExtractor {
    static func texts(in root: Any) -> [String] {
        var result: [String] = []
        collect(in: root, into: &result)
        return result
    }

    private static func collect(in value: Any, into result: inout [String]) {
        if let text = value as? Text {
            if let resolved = resolve(text: text) {
                result.append(resolved)
            }
            return
        }
        for child in Mirror(reflecting: value).children {
            collect(in: child.value, into: &result)
        }
    }

    private static func resolve(text: Text) -> String? {
        guard let storage = Mirror(reflecting: text).children.first(where: { $0.label == "storage" })?.value else {
            return nil
        }
        let storageMirror = Mirror(reflecting: storage)
        if let verbatim = storageMirror.children.first(where: { $0.label == "verbatim" })?.value as? String {
            return verbatim
        }
        if let anyStorage = storageMirror.children.first(where: { $0.label == "anyTextStorage" })?.value,
           let key = Mirror(reflecting: anyStorage).children.first(where: { $0.label == "key" })?.value
            as? LocalizedStringKey {
            return resolve(localizedKey: key)
        }
        return nil
    }

    private static func resolve(localizedKey: LocalizedStringKey) -> String? {
        let mirror = Mirror(reflecting: localizedKey)
        guard var key = mirror.children.first(where: { $0.label == "key" })?.value as? String else {
            return nil
        }
        if let rawArgs = mirror.children.first(where: { $0.label == "arguments" })?.value as? [Any] {
            for arg in rawArgs {
                guard let argValue = extractFormattedValue(from: arg) else { continue }
                for placeholder in ["%lld", "%ld", "%d", "%@"] {
                    if let range = key.range(of: placeholder) {
                        key.replaceSubrange(range, with: String(describing: argValue))
                        break
                    }
                }
            }
        }
        return key
    }

    private static func extractFormattedValue(from argument: Any) -> Any? {
        guard let storage = Mirror(reflecting: argument).children.first(where: { $0.label == "storage" })?.value else {
            return nil
        }
        let storageMirror = Mirror(reflecting: storage)
        guard let tuple = storageMirror.children.first(where: { $0.label == "value" })?.value else {
            return nil
        }
        return Mirror(reflecting: tuple).children.first?.value
    }
}

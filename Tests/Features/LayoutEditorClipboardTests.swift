import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorClipboardTests {
    private struct TestContext {
        let viewModel: LayoutEditorViewModel
        let layout: Layout
        let booths: [LayoutObject]
    }

    private static func makeContext(layer: EditorLayer = .booths) -> TestContext {
        let session = ProjectSession()
        let project = session.createProject(named: "Clipboard Test")
        let legend = PreviewLayouts.sampleLegend
        let categoryID = legend.entries.first?.id
        let booths = (1...3).map { index in
            LayoutObject(
                kind: .booth,
                label: "B\(index)",
                placement: Placement(
                    center: SIMD2<Double>(Double(index) * 5.0, 5.0),
                    sizeM: SIMD2<Double>(2.0, 2.0)
                ),
                categoryID: categoryID,
                openSides: .bottom
            )
        }
        let layout = Layout(name: "Hall", sizeM: SIMD2<Double>(30, 30), objects: booths)
        session.setDraft(ProjectDraft(name: "Clipboard Test", legend: legend, layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.activeLayer = layer
        viewModel.refreshDerivedState()
        return TestContext(viewModel: viewModel, layout: layout, booths: booths)
    }

    @Test("Copying and pasting a single booth offsets it, assigns a new ID and unique label, and selects it")
    func singleBoothCopyAndPaste() throws {
        let context = Self.makeContext()
        let original = context.booths[0]
        let existingLabels = Set(context.booths.map(\.label))

        context.viewModel.selectObject(original.id)
        #expect(context.viewModel.canCopy)
        #expect(!context.viewModel.canPaste)

        context.viewModel.copySelected()
        #expect(context.viewModel.canPaste)

        context.viewModel.pasteClipboard()

        let objects = try #require(context.viewModel.activeLayout?.objects)
        #expect(objects.count == context.booths.count + 1)
        #expect(objects.contains { $0.id == original.id })
        let pasted = try #require(context.viewModel.selectedObject)
        #expect(context.viewModel.groupSelection == nil)
        #expect(pasted.id != original.id)
        #expect(pasted.kind == original.kind)
        #expect(pasted.placement.sizeM == original.placement.sizeM)
        #expect(pasted.categoryID == original.categoryID)
        #expect(simd_distance(pasted.placement.center, original.placement.center) > 0.1)
        #expect(!pasted.label.isEmpty)
        #expect(!existingLabels.contains(pasted.label))
    }

    @Test("Repeated pastes advance the offset so copies do not stack and keep distinct IDs and labels")
    func repeatedPastesAdvanceOffset() throws {
        let context = Self.makeContext()
        let original = context.booths[0]
        context.viewModel.selectObject(original.id)
        context.viewModel.copySelected()

        context.viewModel.pasteClipboard()
        let first = try #require(context.viewModel.selectedObject)

        context.viewModel.pasteClipboard()
        let second = try #require(context.viewModel.selectedObject)

        let objects = try #require(context.viewModel.activeLayout?.objects)
        #expect(objects.count == context.booths.count + 2)
        #expect(Set([original.id, first.id, second.id]).count == 3)
        #expect(simd_distance(first.placement.center, original.placement.center) > 0.1)
        #expect(simd_distance(second.placement.center, original.placement.center) > 0.1)
        #expect(simd_distance(second.placement.center, first.placement.center) > 0.1)
        #expect(Set(objects.map(\.label)).count == objects.count)
    }

    @Test("Copying and pasting a multi-object selection offsets all members with unique IDs and labels")
    func multiObjectCopyAndPaste() throws {
        let context = Self.makeContext()
        let originals = [context.booths[0], context.booths[1]]
        let originalIDs = Set(context.booths.map(\.id))
        context.viewModel.selectBooths(Set(originals.map(\.id)))
        #expect(context.viewModel.canCopy)

        context.viewModel.copySelected()
        context.viewModel.pasteClipboard()

        let objects = try #require(context.viewModel.activeLayout?.objects)
        #expect(objects.count == context.booths.count + 2)
        #expect(context.viewModel.selectionID == nil)
        #expect(context.viewModel.groupMemberIDs.count == 2)
        #expect(context.viewModel.groupMemberIDs.isDisjoint(with: originalIDs))
        #expect(Set(objects.map(\.label)).count == objects.count)

        let pasted = context.viewModel.selectedGroupMembers
        #expect(pasted.count == 2)
        let originalCentroid = (originals[0].placement.center + originals[1].placement.center) / 2.0
        let pastedCentroid = (pasted[0].placement.center + pasted[1].placement.center) / 2.0
        let offset = pastedCentroid - originalCentroid
        #expect(simd_length(offset) > 0.1)

        let expectedCenters = originals.map { $0.placement.center + offset }
        for expected in expectedCenters {
            #expect(pasted.contains { simd_distance($0.placement.center, expected) < 1e-6 })
        }
    }

    @Test("Multi-object paste undoes and redoes in a single atomic step")
    func multiObjectPasteAtomicUndoAndRedo() throws {
        let context = Self.makeContext()
        let originalIDs = Set(context.booths.map(\.id))
        context.viewModel.selectBooths(Set([context.booths[0].id, context.booths[1].id]))
        context.viewModel.copySelected()
        context.viewModel.pasteClipboard()

        let pastedIDs = context.viewModel.groupMemberIDs
        #expect(pastedIDs.count == 2)
        #expect(context.viewModel.canUndo)

        context.viewModel.undo()

        let afterUndo = try #require(context.viewModel.activeLayout?.objects)
        #expect(afterUndo.count == context.booths.count)
        #expect(Set(afterUndo.map(\.id)) == originalIDs)
        #expect(!context.viewModel.canUndo)
        #expect(context.viewModel.canRedo)

        context.viewModel.redo()

        let afterRedo = try #require(context.viewModel.activeLayout?.objects)
        #expect(afterRedo.count == context.booths.count + 2)
        #expect(pastedIDs.isSubset(of: Set(afterRedo.map(\.id))))
        #expect(context.viewModel.canUndo)
        #expect(!context.viewModel.canRedo)
    }

    @Test("Single-object paste undoes and redoes in a single step")
    func singleObjectPasteUndoAndRedo() throws {
        let context = Self.makeContext()
        let original = context.booths[0]
        context.viewModel.selectObject(original.id)
        context.viewModel.copySelected()
        context.viewModel.pasteClipboard()

        let pastedID = try #require(context.viewModel.selectionID)
        #expect(pastedID != original.id)

        context.viewModel.undo()

        let afterUndo = try #require(context.viewModel.activeLayout?.objects)
        #expect(afterUndo.count == context.booths.count)
        #expect(!afterUndo.contains { $0.id == pastedID })
        #expect(!context.viewModel.canUndo)
        #expect(context.viewModel.canRedo)

        context.viewModel.redo()

        let afterRedo = try #require(context.viewModel.activeLayout?.objects)
        #expect(afterRedo.count == context.booths.count + 1)
        #expect(afterRedo.contains { $0.id == pastedID })
        #expect(context.viewModel.canUndo)
        #expect(!context.viewModel.canRedo)
    }

    @Test("Pasting after deleting a middle booth assigns a non-repeating label")
    func pastedLabelsNeverRepeatAfterDelete() throws {
        let context = Self.makeContext()
        let previousLabels = Set(context.booths.map(\.label))

        context.viewModel.selectObject(context.booths[1].id)
        context.viewModel.deleteSelected()

        context.viewModel.selectObject(context.booths[0].id)
        context.viewModel.copySelected()
        context.viewModel.pasteClipboard()

        let pasted = try #require(context.viewModel.selectedObject)
        #expect(!pasted.label.isEmpty)
        #expect(!previousLabels.contains(pasted.label))
    }

    @Test("Pasting with an empty clipboard is a no-op")
    func pasteWithEmptyClipboardIsNoOp() {
        let context = Self.makeContext()
        #expect(!context.viewModel.canPaste)

        context.viewModel.pasteClipboard()

        #expect(context.viewModel.activeLayout == context.layout)
        #expect(!context.viewModel.canUndo)
    }

    @Test("Copying with no selection is a no-op and preserves an existing clipboard")
    func copyWithNoSelectionIsNoOp() throws {
        let context = Self.makeContext()
        #expect(!context.viewModel.canCopy)
        #expect(!context.viewModel.canPaste)

        context.viewModel.copySelected()
        #expect(!context.viewModel.canPaste)
        #expect(context.viewModel.activeLayout == context.layout)

        context.viewModel.selectObject(context.booths[0].id)
        context.viewModel.copySelected()
        #expect(context.viewModel.canPaste)

        context.viewModel.selectObject(nil)
        #expect(!context.viewModel.canCopy)
        context.viewModel.copySelected()
        #expect(context.viewModel.canPaste)

        context.viewModel.pasteClipboard()
        let objects = try #require(context.viewModel.activeLayout?.objects)
        #expect(objects.count == context.booths.count + 1)
    }

    @Test("Clipboard snapshots remain pasteable after the original object is deleted")
    func clipboardSurvivesOriginalDeletion() throws {
        let context = Self.makeContext()
        let original = context.booths[0]
        context.viewModel.selectObject(original.id)
        context.viewModel.copySelected()
        context.viewModel.deleteSelected()

        #expect(context.viewModel.canPaste)
        context.viewModel.pasteClipboard()

        let objects = try #require(context.viewModel.activeLayout?.objects)
        #expect(objects.count == context.booths.count)
        let pasted = try #require(context.viewModel.selectedObject)
        #expect(pasted.id != original.id)
        #expect(pasted.placement.sizeM == original.placement.sizeM)
    }

    @Test("Pasting after switching layers switches activeLayer to the pasted objects' layer before selecting")
    func pasteAfterLayerSwitchSwitchesToPastedLayer() throws {
        let context = Self.makeContext(layer: .booths)
        let original = context.booths[0]
        context.viewModel.selectObject(original.id)
        context.viewModel.copySelected()

        context.viewModel.selectLayer(.structure)
        #expect(context.viewModel.activeLayer == .structure)

        context.viewModel.pasteClipboard()

        #expect(context.viewModel.activeLayer == .booths)
        let pasted = try #require(context.viewModel.selectedObject)
        #expect(pasted.id != original.id)
        #expect(pasted.kind.layer == context.viewModel.activeLayer)
    }
}

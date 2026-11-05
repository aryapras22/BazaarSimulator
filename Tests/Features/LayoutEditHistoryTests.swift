import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutEditHistoryTests {
    @Test("Undo after a move restores the position and redo moves it again")
    func undoAndRedoRestorePosition() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(4, 4), sizeM: SIMD2<Double>(2, 2))
        )
        var movedBooth = initialBooth
        movedBooth.placement.center = SIMD2<Double>(6, 8)
        let edit = LayoutEdit.replace(before: initialBooth, after: movedBooth)

        var layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [initialBooth])
        var history = LayoutEditHistory()

        layout = LayoutEditing.apply(edit, to: layout)
        history.record(edit)
        #expect(layout.objects[0].placement.center == SIMD2<Double>(6, 8))

        if let undoEdit = history.undo() {
            layout = LayoutEditing.apply(undoEdit, to: layout)
        }
        #expect(layout.objects[0].placement.center == SIMD2<Double>(4, 4))

        if let redoEdit = history.redo() {
            layout = LayoutEditing.apply(redoEdit, to: layout)
        }
        #expect(layout.objects[0].placement.center == SIMD2<Double>(6, 8))
    }

    @Test("A new edit clears redo")
    func newEditClearsRedo() {
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(4, 4), sizeM: SIMD2<Double>(2, 2))
        )
        var history = LayoutEditHistory()
        history.record(.insert(booth, index: 0))
        _ = history.undo()
        #expect(history.canRedo)

        history.record(.insert(booth, index: 0))

        #expect(!history.canRedo)
    }

    @Test("The history caps at 200 entries")
    func historyCapsAtTwoHundred() {
        var history = LayoutEditHistory()
        for idx in 0..<250 {
            let booth = LayoutObject(
                kind: .booth,
                label: "B\(idx)",
                placement: Placement(center: SIMD2<Double>(Double(idx), 0), sizeM: SIMD2<Double>(2, 2))
            )
            history.record(.insert(booth, index: idx))
        }

        #expect(history.undoStack.count == 200)
        if case let .insert(oldestKept, _) = history.undoStack.first {
            #expect(oldestKept.label == "B50")
        } else {
            Issue.record("Expected oldest kept insert edit")
        }
    }

    @Test("A batch is one undo step")
    func batchIsOneUndoStep() {
        let boothA = LayoutObject(
            kind: .booth,
            label: "A1",
            placement: Placement(center: SIMD2<Double>(4, 4), sizeM: SIMD2<Double>(2, 2))
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "A2",
            placement: Placement(center: SIMD2<Double>(8, 4), sizeM: SIMD2<Double>(2, 2))
        )
        var layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [boothA, boothB])
        let batch = LayoutEdit.batch([.delete(boothB, index: 1), .delete(boothA, index: 0)])
        var history = LayoutEditHistory()

        layout = LayoutEditing.apply(batch, to: layout)
        history.record(batch)
        if let undoEdit = history.undo() {
            layout = LayoutEditing.apply(undoEdit, to: layout)
        }

        #expect(layout.objects.map(\.label) == ["A1", "A2"])
        #expect(!history.canUndo)
    }

    @Test("Multiple replaces with the same coalesceKey merge into a single replace")
    func multipleReplacesWithSameKeyMerge() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 2))
        )
        var boothB = initialBooth
        boothB.placement.center = SIMD2<Double>(1, 0)
        var boothC = initialBooth
        boothC.placement.center = SIMD2<Double>(2, 0)

        var history = LayoutEditHistory()
        history.record(.replace(before: initialBooth, after: boothB), coalesceKey: "drag-B1")
        history.record(.replace(before: boothB, after: boothC), coalesceKey: "drag-B1")

        #expect(history.undoStack.count == 1)
        #expect(history.undoStack.first == .replace(before: initialBooth, after: boothC))
    }

    @Test("Calling seal stops coalescing so subsequent edits become new steps")
    func sealStopsCoalescing() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 2))
        )
        var boothB = initialBooth
        boothB.placement.center = SIMD2<Double>(1, 0)
        var boothC = initialBooth
        boothC.placement.center = SIMD2<Double>(2, 0)

        var history = LayoutEditHistory()
        history.record(.replace(before: initialBooth, after: boothB), coalesceKey: "drag-B1")
        history.seal()
        history.record(.replace(before: boothB, after: boothC), coalesceKey: "drag-B1")

        #expect(history.undoStack.count == 2)
        #expect(history.undoStack[0] == .replace(before: initialBooth, after: boothB))
        #expect(history.undoStack[1] == .replace(before: boothB, after: boothC))
    }

    @Test("Single undo after a coalesced run restores the initial state")
    func singleUndoAfterCoalescedRunRestoresInitialState() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 2))
        )
        var booth1 = initialBooth
        booth1.placement.center = SIMD2<Double>(1, 1)
        var booth2 = initialBooth
        booth2.placement.center = SIMD2<Double>(2, 2)
        var booth3 = initialBooth
        booth3.placement.center = SIMD2<Double>(3, 3)

        var layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [initialBooth])
        var history = LayoutEditHistory()

        layout = LayoutEditing.apply(.replace(before: initialBooth, after: booth1), to: layout)
        history.record(.replace(before: initialBooth, after: booth1), coalesceKey: "drag-B1")

        layout = LayoutEditing.apply(.replace(before: booth1, after: booth2), to: layout)
        history.record(.replace(before: booth1, after: booth2), coalesceKey: "drag-B1")

        layout = LayoutEditing.apply(.replace(before: booth2, after: booth3), to: layout)
        history.record(.replace(before: booth2, after: booth3), coalesceKey: "drag-B1")

        history.seal()
        #expect(layout.objects[0].placement.center == SIMD2<Double>(3, 3))
        #expect(history.undoStack.count == 1)

        guard let undoEdit = history.undo() else {
            Issue.record("Expected undo edit")
            return
        }
        layout = LayoutEditing.apply(undoEdit, to: layout)
        #expect(layout.objects[0].placement.center == SIMD2<Double>(0, 0))
    }

    @Test("Redo after undo restores the final state of the coalesced gesture")
    func redoAfterUndoRestoresFinalState() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 2))
        )
        var booth1 = initialBooth
        booth1.placement.center = SIMD2<Double>(1, 0)
        var booth2 = initialBooth
        booth2.placement.center = SIMD2<Double>(2, 0)

        var layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [initialBooth])
        var history = LayoutEditHistory()

        layout = LayoutEditing.apply(.replace(before: initialBooth, after: booth1), to: layout)
        history.record(.replace(before: initialBooth, after: booth1), coalesceKey: "nudge-B1")

        layout = LayoutEditing.apply(.replace(before: booth1, after: booth2), to: layout)
        history.record(.replace(before: booth1, after: booth2), coalesceKey: "nudge-B1")

        history.seal()

        if let undoEdit = history.undo() {
            layout = LayoutEditing.apply(undoEdit, to: layout)
        }
        #expect(layout.objects[0].placement.center == SIMD2<Double>(0, 0))

        if let redoEdit = history.redo() {
            layout = LayoutEditing.apply(redoEdit, to: layout)
        }
        #expect(layout.objects[0].placement.center == SIMD2<Double>(2, 0))
    }

    @Test("Replaces with different coalesceKeys do not merge")
    func replacesWithDifferentKeysDoNotMerge() {
        let initialBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(0, 0), sizeM: SIMD2<Double>(2, 2))
        )
        var boothB = initialBooth
        boothB.placement.center = SIMD2<Double>(1, 0)
        var boothC = initialBooth
        boothC.placement.center = SIMD2<Double>(2, 0)

        var history = LayoutEditHistory()
        history.record(.replace(before: initialBooth, after: boothB), coalesceKey: "key-1")
        history.record(.replace(before: boothB, after: boothC), coalesceKey: "key-2")

        #expect(history.undoStack.count == 2)
        #expect(history.undoStack[0] == .replace(before: initialBooth, after: boothB))
        #expect(history.undoStack[1] == .replace(before: boothB, after: boothC))
    }
}

@Suite
@MainActor
struct LayoutEditorCoalesceIntegrationTests {
    @Test("Nudge runs on the same object coalesce into a single undo step")
    func nudgeRunsCoalesceIntoSingleUndoStep() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth])
        session.setDraft(ProjectDraft(name: "Test", layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.selectLayer(.booths)

        viewModel.selectObject(booth.id)
        viewModel.nudgeSelected(by: SIMD2<Double>(0.25, 0))
        viewModel.nudgeSelected(by: SIMD2<Double>(0.25, 0))
        viewModel.nudgeSelected(by: SIMD2<Double>(0.25, 0))

        #expect(viewModel.currentHistory.undoStack.count == 1)
        let moved = try #require(viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(moved.placement.center == SIMD2<Double>(5.75, 5.0))

        viewModel.undo()
        let reverted = try #require(viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(reverted.placement.center == SIMD2<Double>(5.0, 5.0))
        #expect(!viewModel.canUndo)
    }

    @Test("Selection change seals nudge history")
    func selectionChangeSealsNudgeHistory() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(10, 5), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [boothA, boothB])
        session.setDraft(ProjectDraft(name: "Test", layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.selectLayer(.booths)

        viewModel.selectObject(boothA.id)
        viewModel.nudgeSelected(by: SIMD2<Double>(0.25, 0))

        viewModel.selectObject(boothB.id)
        viewModel.nudgeSelected(by: SIMD2<Double>(0.5, 0))

        #expect(viewModel.currentHistory.undoStack.count == 2)
    }

    @Test("Finish dragging object coalesces movements until sealHistory")
    func finishDraggingCoalescesUntilSealHistory() throws {
        let session = ProjectSession()
        let project = session.createProject(named: "Test")
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(4, 4), sizeM: SIMD2<Double>(2, 2)),
            heightM: 2.4
        )
        let layout = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth])
        session.setDraft(ProjectDraft(name: "Test", layouts: [layout]), for: project.id)
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.selectLayer(.booths)

        viewModel.selectObject(booth.id)
        viewModel.finishDraggingObject(id: booth.id, deltaWorld: SIMD2<Double>(1, 0))
        viewModel.finishDraggingObject(id: booth.id, deltaWorld: SIMD2<Double>(1, 0))

        #expect(viewModel.currentHistory.undoStack.count == 1)
        viewModel.sealHistory()
        viewModel.undo()

        let reverted = try #require(viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(reverted.placement.center == SIMD2<Double>(4, 4))
    }
}

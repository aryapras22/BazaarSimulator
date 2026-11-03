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
}

import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct LayoutEditingTests {
    @Test("Apply then inverse returns the original layout for replace, insert, and delete")
    func applyThenInverseRoundTrips() {
        let booth1 = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(4, 4), sizeM: SIMD2<Double>(2, 2))
        )
        let booth2 = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(8, 4), sizeM: SIMD2<Double>(2, 2))
        )
        let original = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth1, booth2])

        var movedBooth1 = booth1
        movedBooth1.placement.center = SIMD2<Double>(5, 5)
        let replaceEdit = LayoutEdit.replace(before: booth1, after: movedBooth1)
        let afterReplace = LayoutEditing.apply(replaceEdit, to: original)
        let restoredReplace = LayoutEditing.apply(LayoutEditing.inverse(of: replaceEdit), to: afterReplace)
        #expect(restoredReplace == original)

        let table = LayoutObject(
            kind: .table,
            label: "T1",
            placement: Placement(center: SIMD2<Double>(12, 12), sizeM: SIMD2<Double>(1, 1))
        )
        let insertEdit = LayoutEdit.insert(table, index: 1)
        let afterInsert = LayoutEditing.apply(insertEdit, to: original)
        let restoredInsert = LayoutEditing.apply(LayoutEditing.inverse(of: insertEdit), to: afterInsert)
        #expect(restoredInsert == original)

        let deleteEdit = LayoutEdit.delete(booth1, index: 0)
        let afterDelete = LayoutEditing.apply(deleteEdit, to: original)
        let restoredDelete = LayoutEditing.apply(LayoutEditing.inverse(of: deleteEdit), to: afterDelete)
        #expect(restoredDelete == original)
    }

    @Test("A batch applies in order and its inverse restores the original layout")
    func batchAppliesInOrderAndInverts() {
        let booth = makeBooth("B1", centerX: 4)
        let original = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: [booth])
        var first = booth
        first.placement.center = SIMD2<Double>(5, 5)
        var second = first
        second.placement.center = SIMD2<Double>(6, 6)
        let batch = LayoutEdit.batch([
            .replace(before: booth, after: first),
            .replace(before: first, after: second)
        ])

        let applied = LayoutEditing.apply(batch, to: original)
        let restored = LayoutEditing.apply(LayoutEditing.inverse(of: batch), to: applied)

        #expect(applied.objects[0].placement.center == SIMD2<Double>(6, 6))
        #expect(restored == original)
    }

    @Test("Undoing a group delete reinserts every booth at its original index")
    func groupDeleteUndoRestoresIndices() {
        let booths = (0..<5).map { makeBooth("A\($0)", centerX: Double($0) * 3) }
        let original = Layout(name: "Test", sizeM: SIMD2<Double>(20, 20), objects: booths)
        let batch = LayoutEdit.batch([
            .delete(booths[3], index: 3),
            .delete(booths[1], index: 1)
        ])

        let deleted = LayoutEditing.apply(batch, to: original)
        let restored = LayoutEditing.apply(LayoutEditing.inverse(of: batch), to: deleted)

        #expect(deleted.objects.map(\.label) == ["A0", "A2", "A4"])
        #expect(restored.objects.map(\.label) == original.objects.map(\.label))
    }

    private func makeBooth(_ label: String, centerX: Double) -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: label,
            placement: Placement(center: SIMD2<Double>(centerX, 4), sizeM: SIMD2<Double>(2, 2))
        )
    }
}

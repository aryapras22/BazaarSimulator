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
}

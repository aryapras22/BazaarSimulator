import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct DraftLayoutMergerTests {
    @Test("An edited layout survives a second Continue")
    func editedLayoutSurvivesSecondContinue() {
        let layoutID = UUID()
        let originalBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2))
        )
        var movedBooth = originalBooth
        movedBooth.placement.center = SIMD2<Double>(10, 10)

        let imported = Layout(
            id: layoutID,
            name: "Plan 1",
            sizeM: SIMD2<Double>(20, 20),
            objects: [originalBooth]
        )
        let edited = Layout(
            id: layoutID,
            name: "Plan 1",
            sizeM: SIMD2<Double>(20, 20),
            objects: [movedBooth]
        )

        let merged = DraftLayoutMerger.merged(
            imported: [imported],
            existing: [edited],
            legend: Legend()
        )

        #expect(merged.first?.objects.first?.placement.center == SIMD2<Double>(10, 10))
    }

    @Test("A removed file's layout is dropped")
    func removedFileLayoutIsDropped() {
        let first = Layout(name: "Plan 1", sizeM: SIMD2<Double>(20, 20))
        let second = Layout(name: "Plan 2", sizeM: SIMD2<Double>(20, 20))

        let merged = DraftLayoutMerger.merged(
            imported: [first],
            existing: [first, second],
            legend: Legend()
        )

        #expect(merged.map(\.id) == [first.id])
    }

    @Test("A new file's layout is added")
    func newFileLayoutIsAdded() {
        let first = Layout(name: "Plan 1", sizeM: SIMD2<Double>(20, 20))
        let second = Layout(name: "Plan 2", sizeM: SIMD2<Double>(20, 20))

        let merged = DraftLayoutMerger.merged(
            imported: [first, second],
            existing: [first],
            legend: Legend()
        )

        #expect(merged.map(\.id) == [first.id, second.id])
    }

    @Test("Category IDs not in the legend are cleared")
    func categoryIDsNotInLegendAreCleared() {
        let keptEntry = LegendEntry(
            name: "Fashion",
            color: LegendColor(red: 0.2, green: 0.8, blue: 0.2)
        )
        let removedCategoryID = UUID()
        let boothA = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: keptEntry.id
        )
        let boothB = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Placement(center: SIMD2<Double>(9, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: removedCategoryID
        )
        let layout = Layout(
            name: "Plan 1",
            sizeM: SIMD2<Double>(20, 20),
            objects: [boothA, boothB]
        )

        let merged = DraftLayoutMerger.merged(
            imported: [layout],
            existing: [layout],
            legend: Legend(entries: [keptEntry])
        )

        #expect(merged.first?.objects.first { $0.id == boothA.id }?.categoryID == keptEntry.id)
        #expect(merged.first?.objects.first { $0.id == boothB.id }?.categoryID == nil)
    }

    @Test("Missing boothType is filled from the matched legend entry on merge")
    func missingBoothTypeIsFilledFromLegend() {
        let foodEntry = LegendEntry(name: "FNB", color: LegendColor(red: 1, green: 0, blue: 0), type: .fnb)
        let booth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: foodEntry.id
        )
        let layout = Layout(name: "Plan 1", sizeM: SIMD2<Double>(20, 20), objects: [booth])

        let merged = DraftLayoutMerger.merged(
            imported: [layout],
            existing: [],
            legend: Legend(entries: [foodEntry])
        )

        #expect(merged.first?.objects.first?.boothType == .fnb)
    }
}

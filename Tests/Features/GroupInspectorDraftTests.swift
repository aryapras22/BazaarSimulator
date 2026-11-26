import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct GroupInspectorDraftTests {
    private func booth(_ label: String, boothType: BoothType? = nil, center: SIMD2<Double> = .zero) -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: label,
            placement: Placement(center: center, sizeM: SIMD2<Double>(2.5, 2.5)),
            boothType: boothType
        )
    }

    private func furniture(_ kind: LayoutObjectKind, catalogID: String, sizeM: SIMD2<Double>) -> LayoutObject {
        LayoutObject(
            kind: kind,
            label: "",
            placement: Placement(center: .zero, sizeM: sizeM),
            catalogID: catalogID
        )
    }

    @Test("Members with different booth types show Mixed, equal ones show the shared value")
    func mixedAndSharedValues() {
        #expect(MixedValue<BoothType?>([.fnb, .goods]) == .mixed)
        #expect(MixedValue<BoothType?>([.goods, .goods]) == .shared(.goods))
    }

    @Test("Changing only the category leaves sizes and rotations untouched")
    func categoryChangeLeavesGeometry() {
        var rotated = booth("A1")
        rotated.placement.rotationDegrees = 90
        var draft = GroupInspectorDraft(memberIDs: [rotated.id])
        draft.category = .set(.goods)

        let updated = draft.applied(to: rotated)

        #expect(updated.boothType == .goods)
        #expect(updated.placement.sizeM == rotated.placement.sizeM)
        #expect(updated.placement.rotationDegrees == 90)
    }

    @Test("Changing the width keeps each booth's center")
    func widthChangeKeepsCenters() {
        let members = [booth("A1", center: SIMD2<Double>(3, 4)), booth("A2", center: SIMD2<Double>(9, 4))]
        var draft = GroupInspectorDraft(memberIDs: members.map(\.id))
        draft.widthM = .set(3)

        let updated = members.map { draft.applied(to: $0) }

        #expect(updated.map(\.placement.center) == members.map(\.placement.center))
        #expect(updated.allSatisfy { $0.placement.sizeM.x == 3 && $0.placement.sizeM.y == 2.5 })
    }

    @Test("A fresh draft has no changes")
    func freshDraftHasNoChanges() {
        #expect(!GroupInspectorDraft(memberIDs: []).hasChanges)
    }

    @Test("Setting the seating block turns a table into a seating block")
    func tableBecomesSeating() {
        let table = furniture(.table, catalogID: "table-rect-4", sizeM: SIMD2<Double>(1.2, 0.7))
        var draft = GroupInspectorDraft(memberIDs: [table.id])
        draft.furnitureType = .set(FurnitureModels.seatingBlockID)

        let updated = draft.applied(to: table)

        #expect(updated.kind == .seating)
        #expect(updated.catalogID == FurnitureModels.seatingBlockID)
        #expect(updated.placement.sizeM == FurnitureModels.seatingBlockSizeM)
        #expect(updated.heightM == FurnitureModels.chairHeightM)
    }

    @Test("Setting a table model turns a seating block into that table")
    func seatingBecomesTable() throws {
        let seating = furniture(.seating, catalogID: FurnitureModels.seatingBlockID, sizeM: SIMD2<Double>(3, 2))
        let model = try #require(FurnitureModels.table("table-round-6"))
        var draft = GroupInspectorDraft(memberIDs: [seating.id])
        draft.furnitureType = .set(model.id)

        let updated = draft.applied(to: seating)

        #expect(updated.kind == .table)
        #expect(updated.catalogID == model.id)
        #expect(updated.placement.sizeM == model.sizeM)
        #expect(updated.heightM == FurnitureModels.tableHeightM)
    }

    @Test("A furniture type leaves a booth untouched")
    func furnitureTypeLeavesBoothAlone() {
        let member = booth("A1")
        var draft = GroupInspectorDraft(memberIDs: [member.id])
        draft.furnitureType = .set(FurnitureModels.seatingBlockID)

        #expect(draft.applied(to: member) == member)
    }
}

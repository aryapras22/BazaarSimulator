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
}

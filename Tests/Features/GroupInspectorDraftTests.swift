import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct GroupInspectorDraftTests {
    private func booth(_ label: String, category: UUID? = nil, center: SIMD2<Double> = .zero) -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: label,
            placement: Placement(center: center, sizeM: SIMD2<Double>(2.5, 2.5)),
            categoryID: category
        )
    }

    @Test("Members with different categories show Mixed, equal ones show the shared value")
    func mixedAndSharedValues() {
        let fashion = UUID()

        #expect(MixedValue([fashion, UUID()]) == .mixed)
        #expect(MixedValue([fashion, fashion]) == .shared(fashion))
    }

    @Test("Changing only the category leaves sizes and rotations untouched")
    func categoryChangeLeavesGeometry() {
        let target = UUID()
        var rotated = booth("A1")
        rotated.placement.rotationDegrees = 90
        var draft = GroupInspectorDraft(memberIDs: [rotated.id])
        draft.category = .set(target)

        let updated = draft.applied(to: rotated)

        #expect(updated.categoryID == target)
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

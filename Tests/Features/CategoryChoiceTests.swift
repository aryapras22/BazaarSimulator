import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct CategoryChoiceTests {
    private let legendID = UUID()

    private func booth() -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(2, 2)),
            categoryID: legendID,
            openSides: [.bottom],
            attractiveness: 3
        )
    }

    @Test("Choosing an entertainment entry turns a booth into that attraction")
    func boothBecomesEntertainment() {
        let original = booth()
        var draft = InspectorDraft(object: original)
        draft.choose(.entertainment(.informationDesk))
        let updated = draft.applied(to: original)

        #expect(draft.categoryChoice == .entertainment(.informationDesk))
        #expect(updated.kind == .entertainment)
        #expect(updated.catalogID == EntertainmentType.informationDesk.catalogID)
        #expect(updated.categoryID == nil)
        #expect(updated.placement == original.placement)
        #expect(updated.openSides == original.openSides)
        #expect(updated.attractiveness == 5)
        #expect(!updated.isDisabled)
    }

    @Test("Disabled is an entertainment entry that closes the object to visitors")
    func disabledClosesObject() {
        let original = booth()
        var draft = InspectorDraft(object: original)
        draft.choose(.entertainment(.disabled))
        let updated = draft.applied(to: original)

        #expect(updated.kind == .entertainment)
        #expect(updated.isDisabled)
        #expect(draft.categoryChoice == .entertainment(.disabled))
    }

    @Test("Choosing a legend category turns an attraction back into an open booth")
    func entertainmentBecomesBooth() {
        let original = LayoutObject(
            kind: .entertainment,
            label: "Closed stand",
            placement: Placement(center: SIMD2<Double>(5, 5), sizeM: SIMD2<Double>(4, 3)),
            catalogID: EntertainmentType.disabled.catalogID,
            isDisabled: true
        )
        var draft = InspectorDraft(object: original)
        draft.choose(.booth(legendID))
        let updated = draft.applied(to: original)

        #expect(updated.kind == .booth)
        #expect(updated.categoryID == legendID)
        #expect(updated.catalogID == nil)
        #expect(!updated.isDisabled)
        #expect(draft.categoryChoice == .booth(legendID))
    }

    @Test("A plan label naming an information desk reads as one")
    func informationDeskFromLabel() {
        #expect(EntertainmentType.resolve(catalogID: nil, label: "INFO DESK") == .informationDesk)
        #expect(EntertainmentType.resolve(catalogID: nil, label: "Stage") == .stage)
    }
}

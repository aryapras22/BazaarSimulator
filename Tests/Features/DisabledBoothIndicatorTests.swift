import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct DisabledBoothIndicatorTests {
    private static let placement = Placement(
        center: SIMD2<Double>(5, 5),
        sizeM: SIMD2<Double>(2, 2)
    )

    @Test("A booth with isDisabled true is detected as disabled and a normal booth is not")
    func boothDisabledFlagDetection() {
        let disabledBooth = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Self.placement,
            isDisabled: true
        )
        let activeBooth = LayoutObject(
            kind: .booth,
            label: "B2",
            placement: Self.placement,
            isDisabled: false
        )

        #expect(DisabledObjectIndicator.isDisabled(disabledBooth))
        #expect(!DisabledObjectIndicator.isDisabled(activeBooth))
    }

    @Test("An entertainment object with the disabled catalog ID is detected as disabled")
    func entertainmentWithDisabledCatalogIDIsDetected() {
        let catalogOnlyDisabled = LayoutObject(
            kind: .entertainment,
            label: "Closed stand",
            placement: Self.placement,
            catalogID: EntertainmentType.disabled.catalogID,
            isDisabled: false
        )
        let explicitDisabled = LayoutObject(
            kind: .entertainment,
            label: "Closed stand",
            placement: Self.placement,
            catalogID: EntertainmentType.disabled.catalogID,
            isDisabled: true
        )

        #expect(DisabledObjectIndicator.isDisabled(catalogOnlyDisabled))
        #expect(DisabledObjectIndicator.isDisabled(explicitDisabled))
    }

    @Test("Choosing the disabled entertainment category in InspectorDraft marks the object as disabled")
    func inspectorDraftChoosingDisabledEntertainment() {
        let original = LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Self.placement,
            categoryID: UUID(),
            openSides: [.bottom],
            isDisabled: false
        )
        var draft = InspectorDraft(object: original)
        draft.choose(.entertainment(.disabled))
        let disabledObject = draft.applied(to: original)

        #expect(DisabledObjectIndicator.isDisabled(disabledObject))

        var reopenedDraft = InspectorDraft(object: disabledObject)
        reopenedDraft.choose(.booth(original.categoryID))
        let reopenedBooth = reopenedDraft.applied(to: disabledObject)

        #expect(!DisabledObjectIndicator.isDisabled(reopenedBooth))
    }

    @Test(
        "Active entertainment types are not detected as disabled while disabled entertainment is",
        arguments: [
            EntertainmentType.stage,
            .photobooth,
            .informationDesk,
            .other
        ]
    )
    func activeEntertainmentTypesAreNotDisabled(type: EntertainmentType) {
        let activeObject = LayoutObject(
            kind: .entertainment,
            label: type.displayName,
            placement: Self.placement,
            catalogID: type.catalogID
        )
        let disabledObject = LayoutObject(
            kind: .entertainment,
            label: EntertainmentType.disabled.displayName,
            placement: Self.placement,
            catalogID: EntertainmentType.disabled.catalogID
        )

        #expect(!DisabledObjectIndicator.isDisabled(activeObject))
        #expect(DisabledObjectIndicator.isDisabled(disabledObject))
    }
}

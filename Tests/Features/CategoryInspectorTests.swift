import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct CategoryInspectorTests {
    private let legendID = UUID()

    private func seatingObject(rotationDegrees: Int = 0) -> LayoutObject {
        LayoutObject(
            kind: .seating,
            label: "Audience",
            placement: Placement(
                center: SIMD2(5, 5),
                sizeM: FurnitureModels.seatingBlockSizeM,
                rotationRadians: Double(rotationDegrees) * .pi / 180
            ),
            catalogID: FurnitureModels.seatingBlockID,
            heightM: FurnitureModels.chairHeightM
        )
    }

    private func boothObject(
        sizeM: SIMD2<Double> = SIMD2(2, 2),
        attractiveness: Double = 2,
        isDisabled: Bool = false
    ) -> LayoutObject {
        LayoutObject(
            kind: .booth,
            label: "B1",
            placement: Placement(center: SIMD2(8, 8), sizeM: sizeM),
            categoryID: legendID,
            openSides: [.bottom, .right],
            attractiveness: attractiveness,
            isDisabled: isDisabled
        )
    }

    private func isMultipleOfSeatPitch(_ dimension: Double) -> Bool {
        let seats = FurnitureModels.seatsAlong(dimension)
        return abs(dimension - Double(seats) * FurnitureModels.seatPitchM) < 1e-9
    }

    @Test("Audience seating reports its own category choice distinct from booth and entertainment")
    func seatingCategoryChoiceIsDistinct() {
        let choice = InspectorDraft(object: seatingObject()).categoryChoice

        #expect(choice != .booth(nil))
        for type in EntertainmentType.allCases {
            #expect(choice != .entertainment(type))
        }
    }

    @Test("Choosing audience seating converts a booth into a valid seating block")
    func boothConvertsToAudienceSeating() {
        let seatingChoice = InspectorDraft(object: seatingObject()).categoryChoice
        let original = boothObject(sizeM: SIMD2(2.3, 1.7), isDisabled: true)
        var draft = InspectorDraft(object: original)

        draft.choose(seatingChoice)
        let updated = draft.applied(to: original)

        #expect(draft.categoryChoice == seatingChoice)
        #expect(updated.kind == .seating)
        #expect(updated.catalogID == FurnitureModels.seatingBlockID)
        #expect(updated.categoryID == nil)
        #expect(updated.openSides.isEmpty)
        #expect(!updated.isDisabled)
        #expect(updated.heightM == FurnitureModels.chairHeightM)
        #expect(isMultipleOfSeatPitch(updated.placement.sizeM.x))
        #expect(isMultipleOfSeatPitch(updated.placement.sizeM.y))
        let expectedSeats = FurnitureModels.seatsAlong(updated.placement.sizeM.x)
            * FurnitureModels.seatsAlong(updated.placement.sizeM.y)
        #expect(FurnitureModels.chairs(of: updated).count == expectedSeats)
    }

    @Test("Choosing audience seating converts an entertainment object into a valid seating block")
    func entertainmentConvertsToAudienceSeating() {
        let seatingChoice = InspectorDraft(object: seatingObject()).categoryChoice
        let original = LayoutObject(
            kind: .entertainment,
            label: "Closed stand",
            placement: Placement(center: SIMD2(6, 6), sizeM: SIMD2(4, 3)),
            openSides: [.top],
            catalogID: EntertainmentType.disabled.catalogID,
            isDisabled: true
        )
        var draft = InspectorDraft(object: original)

        draft.choose(seatingChoice)
        let updated = draft.applied(to: original)

        #expect(draft.categoryChoice == seatingChoice)
        #expect(updated.kind == .seating)
        #expect(updated.catalogID == FurnitureModels.seatingBlockID)
        #expect(updated.categoryID == nil)
        #expect(updated.openSides.isEmpty)
        #expect(!updated.isDisabled)
        #expect(updated.heightM == FurnitureModels.chairHeightM)
    }

    @Test("Switching from audience seating to a booth resets catalog, height, and snaps rotation")
    func seatingConvertsToBooth() {
        let original = seatingObject(rotationDegrees: 45)
        var draft = InspectorDraft(object: original)

        draft.choose(.booth(legendID))
        let updated = draft.applied(to: original)

        let expectedHeight = InspectorDraft.defaultHeight(
            for: LayoutObject(kind: .booth, label: "", placement: original.placement)
        )
        #expect(draft.categoryChoice == .booth(legendID))
        #expect(updated.kind == .booth)
        #expect(updated.categoryID == legendID)
        #expect(updated.catalogID == nil)
        #expect(!updated.isDisabled)
        #expect(updated.heightM == expectedHeight)
        #expect(updated.placement.rotationDegrees % LayoutObjectKind.booth.rotationStepDegrees == 0)
    }

    @Test("Switching from audience seating to entertainment snaps rotation and applies default attractiveness 5")
    func seatingConvertsToEntertainment() throws {
        let original = seatingObject(rotationDegrees: 135)
        var draft = InspectorDraft(object: original)

        draft.choose(.entertainment(.stage))
        let updated = draft.applied(to: original)

        let stageHeight = try #require(ObjectCatalog.item(EntertainmentType.stage.catalogID)?.heightM)
        #expect(draft.categoryChoice == .entertainment(.stage))
        #expect(updated.kind == .entertainment)
        #expect(updated.catalogID == EntertainmentType.stage.catalogID)
        #expect(updated.categoryID == nil)
        #expect(!updated.isDisabled)
        #expect(updated.heightM == stageHeight)
        #expect(updated.attractiveness == LayoutObjectKind.entertainment.defaultAttractiveness)
        #expect(updated.placement.rotationDegrees % LayoutObjectKind.entertainment.rotationStepDegrees == 0)
    }

    @Test("Direct LayoutObject creation defaults entertainment attractiveness to 5 and other kinds to 1")
    func directLayoutObjectDefaultAttractiveness() {
        let placement = Placement(center: SIMD2(5, 5), sizeM: SIMD2(4, 3))
        let entertainment = LayoutObject(kind: .entertainment, label: "Stage", placement: placement)
        let customEntertainment = LayoutObject(
            kind: .entertainment,
            label: "Display",
            placement: placement,
            attractiveness: 2
        )
        let booth = LayoutObject(kind: .booth, label: "B1", placement: placement)
        let seating = LayoutObject(kind: .seating, label: "Audience", placement: placement)

        #expect(entertainment.attractiveness == 5)
        #expect(customEntertainment.attractiveness == 2)
        #expect(booth.attractiveness == 1)
        #expect(seating.attractiveness == 1)
    }

    @Test("Converting a booth to entertainment sets attractiveness to 5 while switching attractions keeps custom value")
    func categoryConversionAttractiveness() {
        let booth = boothObject(attractiveness: 2)
        var boothDraft = InspectorDraft(object: booth)

        boothDraft.choose(.entertainment(.stage))
        let converted = boothDraft.applied(to: booth)

        #expect(boothDraft.attractiveness == 5)
        #expect(converted.attractiveness == 5)

        let stage = LayoutObject(
            kind: .entertainment,
            label: "Stage",
            placement: Placement(center: SIMD2(5, 5), sizeM: SIMD2(4, 3)),
            catalogID: EntertainmentType.stage.catalogID,
            attractiveness: 2
        )
        var stageDraft = InspectorDraft(object: stage)

        stageDraft.choose(.entertainment(.photobooth))
        let switched = stageDraft.applied(to: stage)

        #expect(stageDraft.attractiveness == 2)
        #expect(switched.attractiveness == 2)
    }
}

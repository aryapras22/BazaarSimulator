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

    @Test("CategoryChoice has no audience seating case and never converts a booth or attraction to seating")
    func categoryChoiceDoesNotConvertToSeating() {
        let seatingChoice = InspectorDraft(object: seatingObject()).categoryChoice
        #expect(seatingChoice == .booth(nil))

        let originalBooth = boothObject(sizeM: SIMD2(2.3, 1.7), isDisabled: true)
        var boothDraft = InspectorDraft(object: originalBooth)
        boothDraft.choose(seatingChoice)
        let updatedBooth = boothDraft.applied(to: originalBooth)

        #expect(updatedBooth.kind == .booth)
        #expect(updatedBooth.catalogID == nil)

        let originalEntertainment = LayoutObject(
            kind: .entertainment,
            label: "Stage",
            placement: Placement(center: SIMD2(6, 6), sizeM: SIMD2(4, 3)),
            openSides: [.top],
            catalogID: EntertainmentType.stage.catalogID
        )
        var entertainmentDraft = InspectorDraft(object: originalEntertainment)
        entertainmentDraft.choose(seatingChoice)
        let updatedEntertainment = entertainmentDraft.applied(to: originalEntertainment)

        #expect(updatedEntertainment.kind == .booth)
        #expect(updatedEntertainment.kind != .seating)
    }

    @Test("Choosing a booth or entertainment category leaves audience seating unchanged")
    func chooseDoesNotConvertSeatingToBoothOrEntertainment() {
        let original = seatingObject(rotationDegrees: 45)
        var draft = InspectorDraft(object: original)

        draft.choose(.booth(.goods))
        let afterBooth = draft.applied(to: original)

        #expect(draft.kind == .seating)
        #expect(afterBooth == original)
        #expect(afterBooth.kind == .seating)
        #expect(afterBooth.catalogID == FurnitureModels.seatingBlockID)
        #expect(afterBooth.categoryID == nil)
        #expect(afterBooth.boothType == nil)
        #expect(afterBooth.heightM == FurnitureModels.chairHeightM)
        #expect(afterBooth.placement.rotationDegrees == 45)

        draft.choose(.entertainment(.stage))
        let afterEntertainment = draft.applied(to: original)

        #expect(draft.kind == .seating)
        #expect(afterEntertainment == original)
        #expect(afterEntertainment.kind == .seating)
        #expect(afterEntertainment.catalogID == FurnitureModels.seatingBlockID)
        #expect(afterEntertainment.attractiveness == 1)
        #expect(afterEntertainment.placement.rotationDegrees == 45)
    }

    @Test("Audience seating library row is named Audience Seating under the Booths layer")
    @MainActor
    func audienceSeatingLibraryRow() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        context.viewModel.selectLayer(.booths)

        let row = try #require(
            context.viewModel.libraryRows.first { $0.id == FurnitureModels.seatingBlockID }
        )
        #expect(row.title == "Audience Seating")
        #expect(row.category == .furniture)
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

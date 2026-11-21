import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite("Editor3DVenueBuilderTests")
struct Editor3DVenueBuilderTests {
    private func makeObject(
        _ kind: LayoutObjectKind,
        label: String,
        center: SIMD2<Double>,
        size: SIMD2<Double>,
        openSides: OpenSides = [],
        doorFlow: DoorFlow? = nil,
        catalogID: String? = nil,
        isDisabled: Bool = false
    ) -> LayoutObject {
        LayoutObject(
            kind: kind,
            label: label,
            placement: Placement(center: center, sizeM: size),
            openSides: openSides,
            doorFlow: doorFlow,
            catalogID: catalogID,
            isDisabled: isDisabled
        )
    }

    @Test("A layout with booths, walls and an entertainment stage builds a venue with matching counts and positions")
    func layoutWithBoothsWallsAndStage() {
        let boothA = makeObject(.booth, label: "B1", center: SIMD2(4, 4), size: SIMD2(3, 2), openSides: .bottom)
        let boothB = makeObject(.booth, label: "F1", center: SIMD2(10, 4), size: SIMD2(3, 2), openSides: .bottom)
        let wall = makeObject(.wall, label: "W1", center: SIMD2(10, 1), size: SIMD2(18, 0.3))
        let stage = makeObject(
            .entertainment,
            label: "Main Stage",
            center: SIMD2(10, 12),
            size: SIMD2(6, 3),
            openSides: .top,
            catalogID: EntertainmentType.stage.catalogID
        )
        let layout = Layout(
            name: "Hall A",
            sizeM: SIMD2(20, 16),
            objects: [boothA, boothB, wall, stage]
        )

        var builder = Editor3DVenueBuilder()
        let venue = builder.venue(for: layout)

        let expectedBlocks = VenueGeometry.blocks(for: layout)
        let expectedAttractions = VenueGeometry.attractions(in: layout)
        #expect(!venue.blocks.isEmpty)
        #expect(venue.blocks == expectedBlocks)
        #expect(venue.plan == NavigationGrid(layout: layout).plan)
        #expect(venue.attractions == expectedAttractions)
        #expect(venue.attractions.count == 3)
        #expect(venue.attractions.contains(SIMD2<Float>(4, 4)))
        #expect(venue.attractions.contains(SIMD2<Float>(10, 4)))
        #expect(venue.attractions.contains(SIMD2<Float>(10, 12)))
        #expect(venue.blocks.contains { abs($0.center.x - 10) < 0.01 && abs($0.center.z - 1) < 0.01 })
    }

    private func makeDisabledAndSeatingFixture() -> (layout: Layout, wall: LayoutObject) {
        let disabledBooth = makeObject(
            .booth, label: "B-Closed", center: SIMD2(4, 4), size: SIMD2(3, 2), openSides: .bottom, isDisabled: true
        )
        let wall = makeObject(.wall, label: "North Wall", center: SIMD2(10, 1), size: SIMD2(14, 0.3))
        let disabledDoor = makeObject(
            .door, label: "D1", center: SIMD2(10, 1), size: SIMD2(2, 0.3), doorFlow: DoorFlow(direction: .disabled)
        )
        let disabledAttraction = makeObject(
            .entertainment,
            label: "Closed Display",
            center: SIMD2(16, 4),
            size: SIMD2(3, 2),
            catalogID: EntertainmentType.disabled.catalogID,
            isDisabled: true
        )
        let stage = makeObject(
            .entertainment,
            label: "Stage",
            center: SIMD2(10, 13),
            size: SIMD2(5, 2.5),
            openSides: .top,
            catalogID: EntertainmentType.stage.catalogID
        )
        let table = makeObject(
            .table, label: "T1", center: SIMD2(5, 9), size: SIMD2(1.2, 0.7), catalogID: "table-rect-4"
        )
        let seating = makeObject(
            .seating, label: "S1", center: SIMD2(10, 9), size: SIMD2(3, 2), catalogID: FurnitureModels.seatingBlockID
        )
        let layout = Layout(
            name: "Mixed Hall",
            sizeM: SIMD2(20, 16),
            objects: [disabledBooth, wall, disabledDoor, disabledAttraction, stage, table, seating]
        )
        return (layout, wall)
    }

    @Test("Disabled objects and seating match how the analysis scene builds geometry")
    func disabledObjectsAndSeatingMatchAnalysis() {
        let (layout, wall) = makeDisabledAndSeatingFixture()

        var builder = Editor3DVenueBuilder()
        let venue = builder.venue(for: layout)

        #expect(venue.blocks == VenueGeometry.blocks(for: layout))
        #expect(venue.attractions == VenueGeometry.attractions(in: layout))
        #expect(venue.seats == VenueGeometry.seats(in: layout))
        #expect(!venue.seats.isEmpty)
        #expect(venue.blocks.contains(VenueGeometry.solid(wall)))
    }

    @Test("An empty layout builds a venue with only the floor and no attractions or seats")
    func emptyLayoutBuildsEmptyVenue() {
        let layout = Layout(name: "Empty", sizeM: SIMD2(20, 15))

        var builder = Editor3DVenueBuilder()
        let venue = builder.venue(for: layout)

        #expect(venue.blocks == VenueGeometry.blocks(for: layout))
        #expect(venue.blocks.count == 1)
        #expect(venue.attractions.isEmpty)
        #expect(venue.seats.isEmpty)
        #expect(venue.plan == NavigationGrid(layout: layout).plan)
    }

    @Test("Calling with an equal layout preserves the venue identifier")
    func preservesVenueIDForEqualLayout() {
        let booth = makeObject(.booth, label: "B1", center: SIMD2(6, 6), size: SIMD2(3, 2), openSides: .bottom)
        let layout = Layout(name: "Stable", sizeM: SIMD2(20, 15), objects: [booth])
        let copy = layout

        var builder = Editor3DVenueBuilder()
        let first = builder.venue(for: layout)
        let second = builder.venue(for: copy)

        #expect(first.id == second.id)
        #expect(first.blocks == second.blocks)
        #expect(first.plan == second.plan)
    }

    @Test("Adding or editing a booth rotates the venue identifier and updates blocks")
    func rotatesVenueIDWhenBoothAddedOrEdited() {
        let boothA = makeObject(.booth, label: "B1", center: SIMD2(5, 5), size: SIMD2(3, 2), openSides: .bottom)
        let initialLayout = Layout(name: "Editable", sizeM: SIMD2(20, 15), objects: [boothA])

        var builder = Editor3DVenueBuilder()
        let initialVenue = builder.venue(for: initialLayout)

        let boothB = makeObject(.booth, label: "B2", center: SIMD2(12, 5), size: SIMD2(3, 2), openSides: .bottom)
        var addedLayout = initialLayout
        addedLayout.objects.append(boothB)
        let addedVenue = builder.venue(for: addedLayout)

        #expect(addedVenue.id != initialVenue.id)
        #expect(addedVenue.blocks.count > initialVenue.blocks.count)
        #expect(addedVenue.blocks == VenueGeometry.blocks(for: addedLayout))

        var editedLayout = addedLayout
        editedLayout.objects[0].placement.center = SIMD2(7, 8)
        let editedVenue = builder.venue(for: editedLayout)

        #expect(editedVenue.id != addedVenue.id)
        #expect(editedVenue.blocks != addedVenue.blocks)
        #expect(editedVenue.blocks == VenueGeometry.blocks(for: editedLayout))
    }
}

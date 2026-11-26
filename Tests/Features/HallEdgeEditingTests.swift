import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct HallEdgeEditingTests {
    private static let rectHall: [SIMD2<Double>] = [
        SIMD2(2, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)
    ]

    private static let twiceSplitTopHall: [SIMD2<Double>] = [
        SIMD2(2, 2), SIMD2(5, 2), SIMD2(9, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)
    ]

    private static func layout(hall: [SIMD2<Double>] = rectHall, objects: [LayoutObject] = []) -> Layout {
        Layout(name: "Test", sizeM: SIMD2(14, 10), hall: hall, objects: objects)
    }

    private static func populatedLayout() -> (
        layout: Layout,
        leftDoorID: UUID,
        topDoorID: UUID,
        boothID: UUID
    ) {
        let leftDoor = LayoutObject(
            kind: .door,
            label: "D-Left",
            placement: Placement(center: SIMD2(2, 5), sizeM: SIMD2(1, 0.2), rotationRadians: .pi / 2)
        )
        let topDoor = LayoutObject(
            kind: .door,
            label: "D-Top",
            placement: Placement(center: SIMD2(7, 2), sizeM: SIMD2(1, 0.2))
        )
        let booth = LayoutObject(
            kind: .booth,
            label: "B-1",
            placement: Placement(center: SIMD2(7, 5), sizeM: SIMD2(2, 2))
        )
        let layout = Layout(
            name: "Populated",
            sizeM: SIMD2(14, 10),
            hall: rectHall,
            lobby: [SIMD2(4, 8), SIMD2(10, 8), SIMD2(10, 9.5), SIMD2(4, 9.5)],
            objects: [leftDoor, topDoor, booth],
            markers: [
                LayoutMarker(kind: .spawn, label: "Spawn", position: SIMD2(1, 5)),
                LayoutMarker(kind: .exit, label: "Exit", position: SIMD2(13, 5))
            ],
            zones: [
                LayoutZone(label: "A", minX: 2, maxX: 7, labelPosition: SIMD2(4.5, 5))
            ]
        )
        return (layout, leftDoor.id, topDoor.id, booth.id)
    }

    @Test("Splitting a hall edge inserts a vertex snapped to snapCellM and preserves it")
    func splitInsertsSnappedVertex() throws {
        let original = Self.layout()
        let edit = try #require(HallEdges.split(at: SIMD2(5.2, 2.05), in: original, within: 0.5))

        if case .setOutline = edit {
        } else {
            Issue.record("Expected split to return a .setOutline edit")
        }
        let split = LayoutEditing.apply(edit, to: original)
        #expect(split.hall == [SIMD2(2, 2), SIMD2(5.25, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)])
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: edit), to: split) == original)
    }

    @Test("Splitting rejects points snapping to an existing vertex or outside tolerance")
    func splitRejectsExistingVerticesAndDistantPoints() {
        let rect = Self.layout()
        let splitRect = Self.layout(hall: Self.twiceSplitTopHall)

        #expect(HallEdges.split(at: SIMD2(2.05, 2.0), in: rect, within: 0.5) == nil)
        #expect(HallEdges.split(at: SIMD2(11.95, 2.0), in: rect, within: 0.5) == nil)
        #expect(HallEdges.split(at: SIMD2(5.05, 2.0), in: splitRect, within: 0.5) == nil)
        #expect(HallEdges.split(at: SIMD2(7, 5), in: rect, within: 0.5) == nil)
    }

    @Test("Dragging the middle piece of a twice-split edge outward creates a rectangular bump")
    func draggingTwiceSplitMiddleOutwardCreatesBump() throws {
        let middleDoor = LayoutObject(
            kind: .door,
            label: "D-Mid",
            placement: Placement(center: SIMD2(7, 2), sizeM: SIMD2(1, 0.2))
        )
        let sideDoor = LayoutObject(
            kind: .door,
            label: "D-Side",
            placement: Placement(center: SIMD2(3.5, 2), sizeM: SIMD2(1, 0.2))
        )
        let base = Self.layout(objects: [middleDoor, sideDoor])
        let split1 = try #require(HallEdges.split(at: SIMD2(5, 2), in: base, within: 0.5))
        let onceSplit = LayoutEditing.apply(split1, to: base)
        let split2 = try #require(HallEdges.split(at: SIMD2(9, 2), in: onceSplit, within: 0.5))
        let twiceSplit = LayoutEditing.apply(split2, to: onceSplit)

        let move = try #require(HallEdges.move(edge: 1, to: SIMD2(7, 1), in: twiceSplit))

        let expectedHall: [SIMD2<Double>] = [
            SIMD2(2, 2), SIMD2(5, 2), SIMD2(5, 1), SIMD2(9, 1),
            SIMD2(9, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)
        ]
        #expect(move.hall == expectedHall)
        #expect(move.doorPlacements[middleDoor.id]?.center == SIMD2(7, 1))
        #expect(move.doorPlacements[sideDoor.id] == nil)
        let moved = LayoutEditing.apply(move.edit, to: twiceSplit)
        #expect(moved.hall == expectedHall)
        #expect(moved.objects.first { $0.id == middleDoor.id }?.placement.center == SIMD2(7, 1))
        #expect(moved.objects.first { $0.id == sideDoor.id }?.placement.center == SIMD2(3.5, 2))
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: moved) == twiceSplit)
    }

    @Test("Dragging the middle piece of a twice-split edge inward creates a rectangular notch")
    func draggingTwiceSplitMiddleInwardCreatesNotch() throws {
        let original = Self.layout(hall: Self.twiceSplitTopHall)

        let move = try #require(HallEdges.move(edge: 1, to: SIMD2(7, 4), in: original))

        let expectedHall: [SIMD2<Double>] = [
            SIMD2(2, 2), SIMD2(5, 2), SIMD2(5, 4), SIMD2(9, 4),
            SIMD2(9, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)
        ]
        #expect(move.hall == expectedHall)
        let moved = LayoutEditing.apply(move.edit, to: original)
        #expect(moved.hall == expectedHall)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: moved) == original)
    }

    @Test("Dragging one half of a once-split edge shifts the corner and inserts one step vertex")
    func draggingOnceSplitPieceCreatesStep() throws {
        let hall: [SIMD2<Double>] = [SIMD2(2, 2), SIMD2(6, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)]
        let original = Self.layout(hall: hall)

        let move = try #require(HallEdges.move(edge: 0, to: SIMD2(4, 1), in: original))

        #expect(move.hall == [SIMD2(2, 1), SIMD2(6, 1), SIMD2(6, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)])
    }

    @Test("Dragging an unsplit edge shifts both endpoints without adding vertices")
    func draggingUnsplitEdgeShiftsBothEndpoints() throws {
        let original = Self.layout()

        let move = try #require(HallEdges.move(edge: 0, to: SIMD2(7, 1), in: original))

        #expect(move.hall == [SIMD2(2, 1), SIMD2(12, 1), SIMD2(12, 8), SIMD2(2, 8)])
        let moved = LayoutEditing.apply(move.edit, to: original)
        #expect(moved.hall == move.hall)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: moved) == original)
    }

    @Test("Dragging past x = 0 shifts hall, lobby, objects, markers, and zones on commit")
    func draggingPastNegativeXShiftsWholeLayout() throws {
        let fixture = Self.populatedLayout()
        let original = fixture.layout

        let move = try #require(HallEdges.move(edge: 3, to: SIMD2(-3, 5), in: original))

        #expect(move.hall == [SIMD2(-3, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(-3, 8)])
        #expect(move.doorPlacements[fixture.leftDoorID]?.center == SIMD2(-3, 5))
        let committed = LayoutEditing.apply(move.edit, to: original)
        #expect(committed.hall == [SIMD2(0, 2), SIMD2(15, 2), SIMD2(15, 8), SIMD2(0, 8)])
        #expect(committed.lobby == [SIMD2(7, 8), SIMD2(13, 8), SIMD2(13, 9.5), SIMD2(7, 9.5)])
        #expect(committed.objects.first { $0.id == fixture.leftDoorID }?.placement.center == SIMD2(0, 5))
        #expect(committed.objects.first { $0.id == fixture.topDoorID }?.placement.center == SIMD2(10, 2))
        #expect(committed.objects.first { $0.id == fixture.boothID }?.placement.center == SIMD2(10, 5))
        #expect(committed.markers.map(\.position) == [SIMD2(4, 5), SIMD2(16, 5)])
        #expect(committed.zones[0].minX == 5)
        #expect(committed.zones[0].maxX == 10)
        #expect(committed.zones[0].labelPosition == SIMD2(7.5, 5))
        #expect(committed.sizeM.x >= 15 && committed.sizeM.y >= 10)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed) == original)
    }

    @Test("Dragging past y = 0 shifts the layout vertically without altering zone X bounds")
    func draggingPastNegativeYShiftsWholeLayout() throws {
        let fixture = Self.populatedLayout()
        let original = fixture.layout

        let move = try #require(HallEdges.move(edge: 0, to: SIMD2(7, -2.5), in: original))

        #expect(move.hall == [SIMD2(2, -2.5), SIMD2(12, -2.5), SIMD2(12, 8), SIMD2(2, 8)])
        #expect(move.doorPlacements[fixture.topDoorID]?.center == SIMD2(7, -2.5))
        let committed = LayoutEditing.apply(move.edit, to: original)
        #expect(committed.hall == [SIMD2(2, 0), SIMD2(12, 0), SIMD2(12, 10.5), SIMD2(2, 10.5)])
        #expect(committed.lobby == [SIMD2(4, 10.5), SIMD2(10, 10.5), SIMD2(10, 12), SIMD2(4, 12)])
        #expect(committed.objects.first { $0.id == fixture.topDoorID }?.placement.center == SIMD2(7, 0))
        #expect(committed.objects.first { $0.id == fixture.leftDoorID }?.placement.center == SIMD2(2, 7.5))
        #expect(committed.objects.first { $0.id == fixture.boothID }?.placement.center == SIMD2(7, 7.5))
        #expect(committed.markers.map(\.position) == [SIMD2(1, 7.5), SIMD2(13, 7.5)])
        #expect(committed.zones[0].minX == 2)
        #expect(committed.zones[0].maxX == 7)
        #expect(committed.zones[0].labelPosition == SIMD2(4.5, 7.5))
        #expect(committed.sizeM.x >= 14 && committed.sizeM.y >= 10.5)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed) == original)
    }

    @Test("Dragging an edge that remains at or above zero does not shift the layout")
    func nonNegativeDragDoesNotShiftLayout() throws {
        let fixture = Self.populatedLayout()
        let original = fixture.layout

        let move = try #require(HallEdges.move(edge: 3, to: SIMD2(0, 5), in: original))

        let committed = LayoutEditing.apply(move.edit, to: original)
        #expect(committed.hall == [SIMD2(0, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(0, 8)])
        #expect(committed.lobby == original.lobby)
        #expect(committed.markers == original.markers)
        #expect(committed.zones == original.zones)
        #expect(committed.objects.first { $0.id == fixture.leftDoorID }?.placement.center == SIMD2(0, 5))
        #expect(committed.objects.first { $0.id == fixture.topDoorID }?.placement.center == SIMD2(7, 2))
        #expect(committed.objects.first { $0.id == fixture.boothID }?.placement.center == SIMD2(7, 5))
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed) == original)
    }

    @Test("Undoing a shifted drag restores non-dyadic floating-point geometry bit-exactly")
    func shiftedDragUndoRestoresNonDyadicGeometryBitExactly() throws {
        let booth = LayoutObject(
            kind: .booth,
            label: "B-Float",
            placement: Placement(center: SIMD2(7.1, 5.2), sizeM: SIMD2(2.3, 1.7))
        )
        let original = Layout(
            name: "FloatPrecision",
            sizeM: SIMD2(14.3, 10.1),
            hall: [SIMD2(2.1, 2.2), SIMD2(12.1, 2.2), SIMD2(12.1, 8.2), SIMD2(2.1, 8.2)],
            lobby: [SIMD2(4.1, 8.2), SIMD2(10.3, 8.2), SIMD2(10.3, 9.7), SIMD2(4.1, 9.7)],
            objects: [booth],
            markers: [LayoutMarker(kind: .spawn, label: "In", position: SIMD2(0.1, 0.2))],
            zones: [LayoutZone(label: "A", minX: 0.1, maxX: 6.3, labelPosition: SIMD2(3.2, 4.7))]
        )

        let move = try #require(HallEdges.move(edge: 3, to: SIMD2(-3.15, 5.2), in: original))
        let committed = LayoutEditing.apply(move.edit, to: original)
        let undone = LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed)

        #expect(undone == original)
    }

    @Test("Dragging a bump flush with its parent edge collapses zero-length edges and collinear vertices")
    func draggingBumpFlushCleansUpToRectangle() throws {
        let bumpedHall: [SIMD2<Double>] = [
            SIMD2(2, 2), SIMD2(5, 2), SIMD2(5, 1), SIMD2(9, 1),
            SIMD2(9, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8)
        ]
        let original = Self.layout(hall: bumpedHall)

        let move = try #require(HallEdges.move(edge: 2, to: SIMD2(7, 2), in: original))

        #expect(move.hall == Self.rectHall)
        let committed = LayoutEditing.apply(move.edit, to: original)
        #expect(committed.hall == Self.rectHall)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed) == original)
    }

    @Test("Collinear cleanup collapses flush edges across vertex zero wrap-around")
    func collinearCleanupHandlesWrapAround() throws {
        let steppedHall: [SIMD2<Double>] = [
            SIMD2(1, 2), SIMD2(12, 2), SIMD2(12, 8), SIMD2(2, 8), SIMD2(2, 5), SIMD2(1, 5)
        ]
        let original = Self.layout(hall: steppedHall)

        let move = try #require(HallEdges.move(edge: 5, to: SIMD2(2, 3.5), in: original))

        #expect(move.hall == Self.rectHall)
        let committed = LayoutEditing.apply(move.edit, to: original)
        #expect(committed.hall == Self.rectHall)
        #expect(LayoutEditing.apply(LayoutEditing.inverse(of: move.edit), to: committed) == original)
    }
}

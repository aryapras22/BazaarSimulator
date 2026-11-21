import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelFurnitureTests {
    private func freeSpot(for kind: LayoutObjectKind, size: SIMD2<Double>, in layout: Layout) -> SIMD2<Double>? {
        for row in stride(from: 4.0, to: layout.sizeM.y - 4, by: 2) {
            for column in stride(from: 4.0, to: layout.sizeM.x - 4, by: 2) {
                let candidate = PlacementResolver.resolve(
                    size: size, at: SIMD2(column, row), extraRotationDegrees: 0, kind: kind, in: layout, free: false
                )
                if candidate.isValid { return candidate.placement.center }
            }
        }
        return nil
    }

    @Test("The Booths library offers the 4-seat table and the seating block")
    func libraryOffersStandardModels() {
        let context = LayoutEditorViewModelTests.makeContext()
        context.viewModel.selectLayer(.booths)
        let rows = context.viewModel.libraryRows.filter { $0.category == .furniture }

        #expect(rows.map(\.id) == ["table-rect-4", FurnitureModels.seatingBlockID])
        #expect(rows.allSatisfy { !$0.seats.isEmpty })
        #expect(!context.viewModel.libraryRows.contains { $0.category == .entertainment })
        context.viewModel.selectLayer(.structure)
        #expect(!context.viewModel.libraryRows.contains { $0.category == .furniture })
    }

    @Test("A table is created from the library with its model's size, changed by model, and deleted")
    func tableCreateUpdateDelete() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .table, size: SIMD2(1.5, 1.5), in: context.layout))
        let before = context.layout.objects.count

        viewModel.placeLibraryItem(id: "table-round-6", at: spot)

        let created = try #require(viewModel.selectedObject)
        #expect(created.kind == .table)
        #expect(created.catalogID == "table-round-6")
        #expect(created.placement.sizeM == SIMD2(1.5, 1.5))
        #expect(FurnitureModels.chairs(of: created).count == 6)
        #expect(viewModel.activeLayout?.objects.count == before + 1)

        viewModel.editInspectorDraft {
            $0.catalogID = "table-round-8"
            $0.widthM = 1.8
            $0.lengthM = 1.8
            $0.rotationDegrees = 45
        }
        let updated = try #require(viewModel.activeLayout?.objects.first { $0.id == created.id })
        #expect(updated.catalogID == "table-round-8")
        #expect(updated.placement.rotationDegrees == 45)
        #expect(FurnitureModels.chairs(of: updated).count == 8)

        viewModel.deleteSelected()
        #expect(viewModel.activeLayout?.objects.contains { $0.id == created.id } == false)
        viewModel.undo()
        #expect(viewModel.activeLayout?.objects.contains { $0.id == created.id } == true)
    }

    @Test("Placed entertainment opens its free sides and starts at attractiveness 5, which the user can lower")
    func placedEntertainmentHasOpenSides() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .entertainment, size: SIMD2(4, 3), in: context.layout))

        viewModel.placeLibraryItem(id: ObjectCatalog.entertainmentID, at: spot)
        let entertainment = try #require(viewModel.selectedObject)

        #expect(entertainment.kind == .entertainment)
        #expect(entertainment.attractiveness == 5)
        #expect(!entertainment.openSides.isEmpty)
        #expect(entertainment.openSides == OpenSideInference.defaultSide(for: entertainment, in: context.layout))

        viewModel.editInspectorDraft { $0.attractiveness = 2 }
        #expect(viewModel.activeLayout?.objects.first { $0.id == entertainment.id }?.attractiveness == 2)
    }

    @Test("Resizing a seating block changes its seats, and a table keeps its standard size under a group edit")
    func seatingResizeAndGroupEdit() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .seating, size: SIMD2(3, 2), in: context.layout))

        viewModel.placeLibraryItem(id: FurnitureModels.seatingBlockID, at: spot)
        let block = try #require(viewModel.selectedObject)
        #expect(block.kind == .seating)
        #expect(FurnitureModels.chairs(of: block).count == 24)

        viewModel.editInspectorDraft {
            $0.widthM = 4.0
            $0.lengthM = 2.5
        }
        let resized = try #require(viewModel.activeLayout?.objects.first { $0.id == block.id })
        #expect(FurnitureModels.chairs(of: resized).count == 40)

        let table = LayoutObject(
            kind: .table,
            label: "T",
            placement: Placement(center: .zero, sizeM: SIMD2(1.2, 0.7)),
            catalogID: "table-rect-4"
        )
        var draft = GroupInspectorDraft(memberIDs: [table.id])
        draft.widthM = .set(3)
        draft.category = .set(.goods)
        #expect(draft.applied(to: table) == table)
    }

    @Test("Switching audience seating to a table model updates it in place and undo restores the seating block")
    func seatingToTableAndUndo() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .seating, size: FurnitureModels.seatingBlockSizeM, in: context.layout))

        viewModel.placeLibraryItem(id: FurnitureModels.seatingBlockID, at: spot)
        viewModel.rotateSelected()
        let seating = try #require(viewModel.selectedObject)
        let targetModel = try #require(FurnitureModels.table("table-round-6"))

        viewModel.selectFurnitureType(targetModel.id)

        let converted = try #require(viewModel.activeLayout?.objects.first { $0.id == seating.id })
        #expect(converted.id == seating.id)
        #expect(converted.kind == .table)
        #expect(converted.catalogID == targetModel.id)
        #expect(converted.placement.sizeM == targetModel.sizeM)
        #expect(converted.placement.center == seating.placement.center)
        #expect(converted.placement.rotationDegrees == seating.placement.rotationDegrees)
        #expect(viewModel.inspectorDraft?.kind == .table)

        viewModel.undo()

        let restored = try #require(viewModel.activeLayout?.objects.first { $0.id == seating.id })
        #expect(restored.kind == .seating)
        #expect(restored.catalogID == FurnitureModels.seatingBlockID)
        #expect(restored.placement.sizeM == FurnitureModels.seatingBlockSizeM)
        #expect(restored.placement.center == seating.placement.center)
        #expect(restored.placement.rotationDegrees == seating.placement.rotationDegrees)
        #expect(viewModel.inspectorDraft?.kind == .seating)
    }

    @Test("Switching a table to audience seating turns it into a seating block in place and can be undone")
    func tableToSeatingAndUndo() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .seating, size: FurnitureModels.seatingBlockSizeM, in: context.layout))

        viewModel.placeLibraryItem(id: "table-rect-4", at: spot)
        viewModel.rotateSelected()
        let table = try #require(viewModel.selectedObject)

        viewModel.selectFurnitureType(FurnitureModels.seatingBlockID)

        let converted = try #require(viewModel.activeLayout?.objects.first { $0.id == table.id })
        #expect(converted.id == table.id)
        #expect(converted.kind == .seating)
        #expect(converted.catalogID == FurnitureModels.seatingBlockID)
        #expect(converted.placement.sizeM == FurnitureModels.seatingBlockSizeM)
        #expect(converted.placement.center == table.placement.center)
        #expect(converted.placement.rotationDegrees == table.placement.rotationDegrees)
        #expect(viewModel.inspectorDraft?.kind == .seating)

        viewModel.undo()

        let restored = try #require(viewModel.activeLayout?.objects.first { $0.id == table.id })
        #expect(restored.kind == .table)
        #expect(restored.catalogID == "table-rect-4")
        #expect(restored.placement.sizeM == table.placement.sizeM)
        #expect(restored.placement.center == table.placement.center)
        #expect(restored.placement.rotationDegrees == table.placement.rotationDegrees)
        #expect(viewModel.inspectorDraft?.kind == .table)
    }

    @Test("The furniture Type picker lists Audience Seating before table models, and table switching keeps working")
    func pickerOrderAndTableModelSwitch() throws {
        let expectedIDs = [FurnitureModels.seatingBlockID] + FurnitureModels.tables.map(\.id)
        let expectedNames = ["Audience Seating"] + FurnitureModels.tables.map(\.name)
        #expect(FurnitureTypePicker.options.map(\.id) == expectedIDs)
        #expect(FurnitureTypePicker.options.map(\.name) == expectedNames)

        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .table, size: SIMD2(1.8, 1.8), in: context.layout))

        viewModel.placeLibraryItem(id: "table-rect-4", at: spot)
        let original = try #require(viewModel.selectedObject)
        let nextModel = try #require(FurnitureModels.table("table-round-8"))

        viewModel.selectFurnitureType(nextModel.id)

        let switched = try #require(viewModel.activeLayout?.objects.first { $0.id == original.id })
        #expect(switched.kind == .table)
        #expect(switched.catalogID == nextModel.id)
        #expect(switched.placement.sizeM == nextModel.sizeM)
        #expect(switched.placement.center == original.placement.center)
        #expect(switched.placement.rotationDegrees == original.placement.rotationDegrees)
    }
}

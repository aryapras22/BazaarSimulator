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

    @Test("The Booths library offers the 4-seat table, the seating block and the entertainment objects")
    func libraryOffersStandardModels() {
        let context = LayoutEditorViewModelTests.makeContext()
        context.viewModel.selectLayer(.booths)
        let rows = context.viewModel.libraryRows.filter { $0.category == .furniture }

        #expect(rows.map(\.id) == ["table-rect-4", FurnitureModels.seatingBlockID])
        #expect(rows.allSatisfy { !$0.seats.isEmpty })
        let entertainment = context.viewModel.libraryRows.filter { $0.category == .entertainment }
        #expect(entertainment.map(\.id) == ["stage", "photobooth", "competition", "display"])
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

    @Test("A placed photobooth opens its free sides and pulls at full attractiveness")
    func placedEntertainmentHasOpenSides() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let viewModel = context.viewModel
        viewModel.selectLayer(.booths)
        let spot = try #require(freeSpot(for: .entertainment, size: SIMD2(2, 2), in: context.layout))

        viewModel.placeLibraryItem(id: "photobooth", at: spot)
        let photobooth = try #require(viewModel.selectedObject)

        #expect(photobooth.kind == .entertainment)
        #expect(photobooth.attractiveness == 5)
        #expect(!photobooth.openSides.isEmpty)
        #expect(photobooth.openSides == OpenSideInference.defaultSide(for: photobooth, in: context.layout))
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
        draft.category = .set(UUID())
        #expect(draft.applied(to: table) == table)
    }
}

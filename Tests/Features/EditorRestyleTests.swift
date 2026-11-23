import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct EditorRestyleTests {
    @Test("Renaming a booth stores the new label and can be undone")
    func renameBooth() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        context.viewModel.renameSelected(to: "Corner Cafe")

        let renamed = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(renamed.label == "Corner Cafe")
        context.viewModel.undo()
        let restored = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(restored.label == booth.label)
    }

    @Test("Saving changes closes the inspector, keeping the edit")
    func saveClosesInspector() throws {
        let context = LayoutEditorViewModelTests.makeContext()
        let booth = try #require(context.layout.objects.first { $0.kind == .booth })
        context.viewModel.selectObject(booth.id)
        context.viewModel.editInspectorDraft { $0.widthM = 3.5 }
        context.viewModel.saveChanges()

        #expect(context.viewModel.selectionID == nil)
        let edited = try #require(context.viewModel.activeLayout?.objects.first { $0.id == booth.id })
        #expect(edited.placement.sizeM.x == 3.5)
    }

    @Test("Each tab lists its own add buttons")
    func addButtonsPerLayer() {
        #expect(EditorAddTool.tools(for: .booths) == [.booth, .chair])
        #expect(EditorAddTool.tools(for: .structure) == [.wall, .block, .door, .restrictedArea])
    }

    @Test("A structure button switches its tool on and a second press turns it off")
    func toggleTool() {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        context.viewModel.toggle(.restrictedArea)
        #expect(context.viewModel.tool == .blockedArea)
        #expect(context.viewModel.isActive(.restrictedArea))
        context.viewModel.toggle(.restrictedArea)
        #expect(context.viewModel.tool == .select)
    }

    @Test("A button of the other tab does nothing")
    func otherLayerIgnored() {
        let context = LayoutEditorViewModelTests.makeContext(layer: .structure)
        context.viewModel.toggle(.chair)
        #expect(context.viewModel.tool == .select)
    }

    @Test("The chair button on the Floor Plan tab places an audience seating block")
    func toggleChairAddsSeating() {
        let context = LayoutEditorViewModelTests.makeContext(layer: .booths)
        context.viewModel.toggle(.chair)
        #expect(context.viewModel.tool == .place(.catalog(FurnitureModels.seatingBlockID)))
        #expect(context.viewModel.isActive(.chair))
    }

    @Test("Placing audience seating from the chair button defaults to 4 chairs")
    func placeChairToolDefaultsToFourChairs() throws {
        let context = LayoutEditorViewModelTests.makeContext(layer: .booths)
        context.viewModel.toggle(.chair)
        context.viewModel.updatePlacementPreview(at: SIMD2<Double>(20, 10), free: false)
        context.viewModel.commitPlacement(keepTool: false)

        let seating = try #require(context.viewModel.selectedObject)
        #expect(seating.kind == .seating)
        #expect(seating.catalogID == FurnitureModels.seatingBlockID)
        #expect(seating.placement.sizeM == SIMD2<Double>(1.0, 1.0))
        #expect(FurnitureModels.chairs(of: seating).count == 4)
    }

    @Test("The audience seating catalog item defaults to 4 seats")
    func seatingCatalogItemHasFourSeats() throws {
        let item = try #require(ObjectCatalog.item(FurnitureModels.seatingBlockID))
        #expect(item.sizeM == SIMD2<Double>(1.0, 1.0))
        #expect(item.seats.count == 4)
    }
}

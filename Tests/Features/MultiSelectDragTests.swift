import CoreGraphics
import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct MultiSelectDragTests {
    private static let pointsPerMetre: Double = 10.0

    private static func makeViewModel(
        objects: [LayoutObject],
        layer: EditorLayer = .booths
    ) -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Multi-Select Drag")
        let hall: [SIMD2<Double>] = [
            SIMD2<Double>(0, 0),
            SIMD2<Double>(40, 0),
            SIMD2<Double>(40, 40),
            SIMD2<Double>(0, 40)
        ]
        let layout = Layout(
            name: "Main Hall",
            sizeM: SIMD2<Double>(40, 40),
            hall: hall,
            objects: objects
        )
        session.setDraft(
            ProjectDraft(name: "Multi-Select Drag", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.activeLayer = layer
        return viewModel
    }

    private static func makeObject(
        kind: LayoutObjectKind,
        label: String,
        center: SIMD2<Double>,
        sizeM: SIMD2<Double> = SIMD2<Double>(2, 2)
    ) -> LayoutObject {
        LayoutObject(
            kind: kind,
            label: label,
            placement: Placement(center: center, sizeM: sizeM)
        )
    }

    private static func pointerEvent(
        world: SIMD2<Double>,
        hitObjectID: UUID? = nil
    ) -> CanvasPointerEvent {
        CanvasPointerEvent(
            worldPoint: world,
            viewPoint: CGPoint(x: world.x * pointsPerMetre, y: world.y * pointsPerMetre),
            hitObjectID: hitObjectID,
            pointsPerMetre: pointsPerMetre
        )
    }

    private static func drag(
        _ object: LayoutObject,
        by delta: SIMD2<Double>,
        in viewModel: LayoutEditorViewModel
    ) {
        let start = object.placement.center
        let end = start + delta
        viewModel.handlePointerPress(pointerEvent(world: start, hitObjectID: object.id))
        viewModel.handlePointerMove(pointerEvent(world: end, hitObjectID: object.id))
        viewModel.handlePointerRelease(pointerEvent(world: end, hitObjectID: object.id))
    }

    private static func center(of id: UUID, in viewModel: LayoutEditorViewModel) throws -> SIMD2<Double> {
        let object = try #require(viewModel.activeLayout?.objects.first { $0.id == id })
        return object.placement.center
    }

    private static func previewCenter(
        for object: LayoutObject,
        in dragState: CanvasDragState
    ) -> SIMD2<Double> {
        if let placement = dragState.previewPlacements[object.id] {
            return placement.center
        }
        if dragState.objectID == object.id {
            return object.placement.center + dragState.deltaWorld
        }
        return object.placement.center
    }

    @Test("Dragging one of several selected booths moves every selected booth by the same offset")
    func draggingOneOfSeveralSelectedBoothsMovesAllSelected() throws {
        let boothA = Self.makeObject(kind: .booth, label: "B1", center: SIMD2<Double>(5, 5))
        let boothB = Self.makeObject(kind: .booth, label: "B2", center: SIMD2<Double>(10, 5))
        let boothC = Self.makeObject(kind: .booth, label: "B3", center: SIMD2<Double>(15, 5))
        let viewModel = Self.makeViewModel(objects: [boothA, boothB, boothC])
        viewModel.selectBooths([boothA.id, boothB.id])
        let delta = SIMD2<Double>(2, 3)

        Self.drag(boothA, by: delta, in: viewModel)

        #expect(simd_distance(try Self.center(of: boothA.id, in: viewModel), boothA.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothB.id, in: viewModel), boothB.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothC.id, in: viewModel), boothC.placement.center) < 1e-6)
        #expect(viewModel.groupMemberIDs == [boothA.id, boothB.id])
        #expect(viewModel.selectionID == nil)
    }

    @Test("Dragging any member of a multi-selection moves all selected objects by the same offset")
    func draggingAnySelectedMemberMovesAllSelected() throws {
        let boothA = Self.makeObject(kind: .booth, label: "B1", center: SIMD2<Double>(5, 5))
        let boothB = Self.makeObject(kind: .booth, label: "B2", center: SIMD2<Double>(10, 5))
        let boothC = Self.makeObject(kind: .booth, label: "B3", center: SIMD2<Double>(10, 12))
        let viewModel = Self.makeViewModel(objects: [boothA, boothB, boothC])
        viewModel.selectBooths([boothA.id, boothB.id, boothC.id])
        let delta = SIMD2<Double>(3, 4)

        Self.drag(boothC, by: delta, in: viewModel)

        #expect(simd_distance(try Self.center(of: boothA.id, in: viewModel), boothA.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothB.id, in: viewModel), boothB.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothC.id, in: viewModel), boothC.placement.center + delta) < 1e-6)
    }

    @Test("One undo restores every object moved by a multi-selection drag and redo reapplies the move")
    func oneUndoRestoresAllObjectsAfterMultiSelectDrag() throws {
        let boothA = Self.makeObject(kind: .booth, label: "B1", center: SIMD2<Double>(5, 5))
        let boothB = Self.makeObject(kind: .booth, label: "B2", center: SIMD2<Double>(10, 5))
        let boothC = Self.makeObject(kind: .booth, label: "B3", center: SIMD2<Double>(15, 12))
        let viewModel = Self.makeViewModel(objects: [boothA, boothB, boothC])
        viewModel.selectBooths([boothA.id, boothB.id, boothC.id])
        let delta = SIMD2<Double>(2, 3)

        Self.drag(boothA, by: delta, in: viewModel)
        #expect(simd_distance(try Self.center(of: boothA.id, in: viewModel), boothA.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothB.id, in: viewModel), boothB.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothC.id, in: viewModel), boothC.placement.center + delta) < 1e-6)

        viewModel.undo()

        #expect(simd_distance(try Self.center(of: boothA.id, in: viewModel), boothA.placement.center) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothB.id, in: viewModel), boothB.placement.center) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothC.id, in: viewModel), boothC.placement.center) < 1e-6)
        #expect(!viewModel.canUndo)
        #expect(viewModel.canRedo)

        viewModel.redo()

        #expect(simd_distance(try Self.center(of: boothA.id, in: viewModel), boothA.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothB.id, in: viewModel), boothB.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: boothC.id, in: viewModel), boothC.placement.center + delta) < 1e-6)
    }

    @Test("Moving a dragged multi-selection previews every selected object at the offset")
    func movingMultiSelectionPreviewsAllSelectedObjects() {
        let boothA = Self.makeObject(kind: .booth, label: "B1", center: SIMD2<Double>(5, 5))
        let boothB = Self.makeObject(kind: .booth, label: "B2", center: SIMD2<Double>(10, 5))
        let viewModel = Self.makeViewModel(objects: [boothA, boothB])
        viewModel.selectBooths([boothA.id, boothB.id])
        let delta = SIMD2<Double>(2, 3)

        let end = boothA.placement.center + delta
        viewModel.handlePointerPress(Self.pointerEvent(world: boothA.placement.center, hitObjectID: boothA.id))
        viewModel.handlePointerMove(Self.pointerEvent(world: end, hitObjectID: boothA.id))

        let previewA = Self.previewCenter(for: boothA, in: viewModel.dragState)
        let previewB = Self.previewCenter(for: boothB, in: viewModel.dragState)
        #expect(simd_distance(previewA, end) < 1e-6)
        #expect(simd_distance(previewB, boothB.placement.center + delta) < 1e-6)

        viewModel.handlePointerRelease(Self.pointerEvent(world: end, hitObjectID: boothA.id))
        #expect(viewModel.dragState.previewPlacements.isEmpty)
        #expect(viewModel.dragState.objectID == nil)
    }

    @Test("Dragging a structure multi-selection including a restricted area moves all selected and undoes in one step")
    func draggingStructureMultiSelectionMovesAllAndUndoes() throws {
        let block = Self.makeObject(kind: .block, label: "Pillar", center: SIMD2<Double>(5, 5))
        let area = Self.makeObject(
            kind: .closedArea,
            label: "Restricted area",
            center: SIMD2<Double>(12, 5),
            sizeM: SIMD2<Double>(4, 4)
        )
        let viewModel = Self.makeViewModel(objects: [block, area], layer: .structure)
        viewModel.selectBooths([block.id, area.id])
        let delta = SIMD2<Double>(2, 4)

        Self.drag(area, by: delta, in: viewModel)

        #expect(simd_distance(try Self.center(of: block.id, in: viewModel), block.placement.center + delta) < 1e-6)
        #expect(simd_distance(try Self.center(of: area.id, in: viewModel), area.placement.center + delta) < 1e-6)
        #expect(viewModel.groupMemberIDs == [block.id, area.id])

        viewModel.undo()

        #expect(simd_distance(try Self.center(of: block.id, in: viewModel), block.placement.center) < 1e-6)
        #expect(simd_distance(try Self.center(of: area.id, in: viewModel), area.placement.center) < 1e-6)
        #expect(!viewModel.canUndo)
    }
}

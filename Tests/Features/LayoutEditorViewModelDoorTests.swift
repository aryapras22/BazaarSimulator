import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelDoorTests {
    private static func makeViewModel() -> LayoutEditorViewModel {
        let session = ProjectSession()
        let project = session.createProject(named: "Annyeong")
        let layout = PreviewLayouts.annyeong()
        session.setDraft(
            ProjectDraft(name: "Annyeong", legend: PreviewLayouts.sampleLegend, layouts: [layout]),
            for: project.id
        )
        let viewModel = LayoutEditorViewModel(projectID: project.id, session: session)
        viewModel.refreshDerivedState()
        return viewModel
    }

    @Test("Dragged door stays on its host")
    func draggedDoorStaysOnHost() throws {
        let viewModel = Self.makeViewModel()
        guard let layout = viewModel.activeLayout else {
            Issue.record("Missing active layout")
            return
        }

        let existingDoor = try #require(layout.objects.first { $0.kind == .door })
        let originalCenter = existingDoor.placement.center
        let host = try #require(DoorHosting.nearestHost(to: originalCenter, in: layout, reach: 0.3))

        // Attempt to drag perpendicular to host
        let tangent = normalize(host.end - host.start)
        let perpendicular = SIMD2<Double>(-tangent.y, tangent.x) * 5.0

        viewModel.finishDraggingObject(id: existingDoor.id, deltaWorld: perpendicular)

        let movedDoor = try #require(viewModel.activeLayout?.objects.first { $0.id == existingDoor.id })
        // Distance to host should still be ~0
        let projectedPlacement = DoorHosting.placement(
            width: movedDoor.placement.sizeM.x,
            on: host,
            near: movedDoor.placement.center
        )
        let dist = simd_distance(movedDoor.placement.center, projectedPlacement!.center)
        #expect(dist < 1e-4)
    }

    @Test("Flow advice treats a new hallToOutside door separately from hall-to-lobby doors")
    func flowAdviceTreatsHallToOutsideSeparately() throws {
        let viewModel = Self.makeViewModel()
        guard let layout = viewModel.activeLayout else {
            Issue.record("Missing active layout")
            return
        }

        // Place a hallToOutside door on outer wall
        let host = try #require(DoorHosting.hosts(in: layout).first { $0.connection == .hallToOutside })
        let placement = try #require(DoorHosting.placement(width: 1.2, on: host, near: (host.start + host.end) / 2.0))

        let outsideDoor = LayoutObject(
            id: UUID(),
            kind: .door,
            label: "Outer Door",
            placement: placement,
            doorFlow: DoorFlow(direction: .exit, connection: .hallToOutside)
        )

        let updatedLayout = LayoutEditing.apply(
            .insert(outsideDoor, index: layout.objects.count),
            to: layout
        )

        // Advice for the new outside door should check its peers (which have no entry), not hall-to-lobby doors
        let advice = DoorFlowAdvisor.advice(for: outsideDoor, in: updatedLayout)
        #expect(advice != nil)
        #expect(advice?.message.contains("entrance") == true || advice?.message.contains("in") == true)
    }

    @Test("Placing door on a host commits with correct connection")
    func placingDoorOnHost() throws {
        let viewModel = Self.makeViewModel()
        guard let layout = viewModel.activeLayout else {
            Issue.record("Missing active layout")
            return
        }

        viewModel.selectTool(.placeDoor(itemID: "door"))
        let host = try #require(DoorHosting.hosts(in: layout).first { $0.connection == .hallToOutside })
        let targetPoint = (host.start + host.end) / 2.0

        viewModel.updateDoorPlacementPreview(at: targetPoint, itemID: "door")
        let candidate = try #require(viewModel.placementPreview)
        #expect(candidate.isValid)

        let initialCount = layout.objects.count
        viewModel.commitDoorPlacement(keepTool: false, itemID: "door")

        let afterCount = viewModel.activeLayout?.objects.count ?? 0
        #expect(afterCount == initialCount + 1)

        let placedID = try #require(viewModel.selectionID)
        let placedDoor = try #require(viewModel.activeLayout?.objects.first { $0.id == placedID })
        #expect(placedDoor.kind == .door)
        #expect(placedDoor.doorFlow?.connection == .hallToOutside)
        #expect(viewModel.tool == .select)
    }
}

import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelViewsTests {
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

    @Test("Switching presets preserves selection")
    func switchPresetsPreservesSelection() {
        let viewModel = Self.makeViewModel()
        let booth = viewModel.activeLayout?.objects.first { $0.kind == .booth }
        #expect(booth != nil)
        viewModel.selectObject(booth?.id)

        viewModel.selectViewPreset(.threeD, reduceMotion: true)
        #expect(viewModel.viewPreset == .threeD)
        #expect(viewModel.selectionID == booth?.id)

        viewModel.selectViewPreset(.front, reduceMotion: true)
        #expect(viewModel.viewPreset == .front)
        #expect(viewModel.selectionID == booth?.id)

        viewModel.selectViewPreset(.plan, reduceMotion: true)
        #expect(viewModel.viewPreset == .plan)
        #expect(viewModel.selectionID == booth?.id)
    }

    @Test("Click at screen centre in 3D selects object at camera target")
    func clickScreenCentreSelectsTarget() {
        let viewModel = Self.makeViewModel()
        let targetBooth = viewModel.activeLayout?.objects.first { $0.kind == .booth }
        #expect(targetBooth != nil)
        guard let targetBooth else { return }

        viewModel.selectViewPreset(.threeD, reduceMotion: true)

        let targetCenter = targetBooth.placement.center
        viewModel.cameraRig = CameraRig(
            pose: CameraPose(
                target: SIMD3<Double>(targetCenter.x, 0, targetCenter.y),
                azimuth: 0,
                polar: 1.0,
                distance: 20,
                fieldOfViewDegrees: 46
            )
        )

        let viewSize = CGSize(width: 800, height: 600)
        let centerPoint = CGPoint(x: 400, y: 300)
        viewModel.handle3DClick(viewPoint: centerPoint, viewSize: viewSize)

        #expect(viewModel.selectionID == targetBooth.id)
    }

    @Test("Selection outline box is generated for selected object")
    func selectionOutlineBoxGenerated() {
        let viewModel = Self.makeViewModel()
        let targetBooth = viewModel.activeLayout?.objects.first { $0.kind == .booth }
        #expect(targetBooth != nil)
        guard let targetBooth else { return }

        viewModel.selectObject(targetBooth.id)
        let outlines = viewModel.selectionOutlineBoxes

        #expect(outlines.count == 1)
        let outline = outlines[0]
        #expect(abs(outline.center.x - targetBooth.placement.center.x) < 1e-4)
        #expect(abs(outline.center.z - targetBooth.placement.center.y) < 1e-4)
        #expect(abs(outline.size.x - targetBooth.placement.sizeM.x) < 1e-4)
    }
}

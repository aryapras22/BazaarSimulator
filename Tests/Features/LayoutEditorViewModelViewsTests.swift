import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
@MainActor
struct LayoutEditorViewModelViewsTests {
    private static let viewSize = CGSize(width: 800, height: 600)

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

    private static func geometry(
        of viewModel: LayoutEditorViewModel,
        newerThan version: Int
    ) async -> SceneGeometry? {
        for _ in 0..<300 {
            if let geometry = viewModel.sceneGeometry, geometry.version > version {
                return geometry
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }

    private static func panelCentroidX(_ geometry: SceneGeometry) -> Float {
        let positions = geometry.meshes[SceneMaterialKey(role: .panel, tint: nil)]?.positions ?? []
        return positions.map(\.x).reduce(0, +) / Float(max(positions.count, 1))
    }

    @Test("Moving a booth in 3D rebuilds the scene with a newer version")
    func movingBoothRebuildsScene() async {
        let viewModel = Self.makeViewModel()
        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)
        guard let before = await Self.geometry(of: viewModel, newerThan: 0),
              let booth = viewModel.activeLayout?.objects.first(where: { $0.kind == .booth }) else {
            Issue.record("No initial geometry")
            return
        }

        viewModel.finishDraggingObject(id: booth.id, deltaWorld: SIMD2<Double>(3, 0))
        guard let after = await Self.geometry(of: viewModel, newerThan: before.version) else {
            Issue.record("Scene was not rebuilt after the move")
            return
        }

        #expect(after.version > before.version)
        #expect(Self.panelCentroidX(after) > Self.panelCentroidX(before))
    }

    @Test("Back-to-back rebuilds keep only the newest geometry")
    func backToBackRebuildsKeepNewest() async {
        let viewModel = Self.makeViewModel()
        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)

        viewModel.rebuildSceneGeometry()
        viewModel.rebuildSceneGeometry()
        viewModel.rebuildSceneGeometry()
        let latest = viewModel.sceneGeometryGeneration
        _ = await Self.geometry(of: viewModel, newerThan: latest - 1)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.sceneGeometry?.version == latest)
    }

    func switchPresetsPreservesSelection() {
        let viewModel = Self.makeViewModel()
        let booth = viewModel.activeLayout?.objects.first { $0.kind == .booth }
        #expect(booth != nil)
        viewModel.selectObject(booth?.id)

        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)
        #expect(viewModel.viewPreset == .threeD)
        #expect(viewModel.selectionID == booth?.id)

        viewModel.selectViewPreset(.front, reduceMotion: true, viewSize: Self.viewSize)
        #expect(viewModel.viewPreset == .front)
        #expect(viewModel.selectionID == booth?.id)

        viewModel.selectViewPreset(.plan, reduceMotion: true, viewSize: Self.viewSize)
        #expect(viewModel.viewPreset == .plan)
        #expect(viewModel.selectionID == booth?.id)
    }

    @Test("Click at screen centre in 3D selects object at camera target")
    func clickScreenCentreSelectsTarget() {
        let viewModel = Self.makeViewModel()
        let targetBooth = viewModel.activeLayout?.objects.first { $0.kind == .booth }
        #expect(targetBooth != nil)
        guard let targetBooth else { return }

        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)

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

    @Test("Eye view walk and clamping")
    func eyeViewWalkAndClamping() {
        let viewModel = Self.makeViewModel()
        viewModel.selectViewPreset(.eye, reduceMotion: true, viewSize: Self.viewSize)

        #expect(viewModel.cameraRig.eye != nil)
        #expect(viewModel.cameraRig.eye?.position.y == 1.6)

        let initialZ = viewModel.cameraRig.eye?.position.z ?? 0
        viewModel.handle3DWalk(forward: 10.0, right: 0)
        let newZ = viewModel.cameraRig.eye?.position.z ?? 0
        #expect(newZ != initialZ)

        // Walk huge distance to hit bounds clamp
        viewModel.handle3DWalk(forward: 1000.0, right: 0)
        let clampedZ = viewModel.cameraRig.eye?.position.z ?? 0
        viewModel.handle3DWalk(forward: 1000.0, right: 0)
        #expect(viewModel.cameraRig.eye?.position.z == clampedZ)
    }

    @Test("Eye view pitch is clamped to +/- 60 degrees")
    func eyeViewPitchClamp() {
        let viewModel = Self.makeViewModel()
        viewModel.selectViewPreset(.eye, reduceMotion: true, viewSize: Self.viewSize)

        // Look way up
        viewModel.handle3DLook(delta: CGSize(width: 0, height: -10000))
        let maxPitch = Double.pi / 3.0
        #expect(abs((viewModel.cameraRig.eye?.pitch ?? 0) - maxPitch) < 1e-4)

        // Look way down
        viewModel.handle3DLook(delta: CGSize(width: 0, height: 10000))
        #expect(abs((viewModel.cameraRig.eye?.pitch ?? 0) - (-maxPitch)) < 1e-4)
    }

    @Test("Leaving eye preset restores orbit camera")
    func leavingEyeRestoresOrbit() {
        let viewModel = Self.makeViewModel()
        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)
        let orbitPose = viewModel.cameraRig.pose

        viewModel.selectViewPreset(.eye, reduceMotion: true, viewSize: Self.viewSize)
        #expect(viewModel.cameraRig.eye != nil)

        viewModel.selectViewPreset(.threeD, reduceMotion: true, viewSize: Self.viewSize)
        #expect(viewModel.cameraRig.eye == nil)
        #expect(abs(viewModel.cameraRig.pose.polar - orbitPose.polar) < 1e-4)
    }

    @Test("Plan to 3D and straight back keeps the canvas center and zoom")
    func planRoundTripKeepsCanvas() {
        let viewModel = Self.makeViewModel()
        let size = CGSize(width: 1200, height: 700)
        let center = SIMD2<Double>(600, 350)
        viewModel.transform = CanvasTransform(scale: 18, offset: SIMD2<Double>(-120, 40))
        let worldBefore = viewModel.transform.toWorld(center)
        let scaleBefore = viewModel.transform.scale

        // Animated with no frames advanced, so the camera is still on the pose built from the canvas.
        viewModel.selectViewPreset(.threeD, reduceMotion: false, viewSize: size)
        viewModel.selectViewPreset(.plan, reduceMotion: true, viewSize: size)

        let worldAfter = viewModel.transform.toWorld(center)
        #expect(simd_length(worldAfter - worldBefore) < 0.01)
        #expect(abs(viewModel.transform.scale / scaleBefore - 1) < 0.01)
    }
}

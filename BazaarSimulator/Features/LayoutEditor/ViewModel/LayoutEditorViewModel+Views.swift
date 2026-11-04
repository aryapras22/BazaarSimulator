import AppKit
import Foundation
import simd

extension LayoutEditorViewModel {
    func selectViewPreset(
        _ preset: ViewPreset,
        reduceMotion: Bool = false,
        viewSize: CGSize
    ) {
        guard preset != viewPreset else { return }
        if tool != .select && preset != .plan {
            selectTool(.select)
        }
        let bounds = activeLayout.map { LayoutGeometry.bounds(of: $0.hall) }
            ?? BoundingBox(minX: 0, maxX: 40, minY: 0, maxY: 30)
        let aspect = max(viewSize.width / max(viewSize.height, 1), 0.1)

        if viewPreset == .plan && preset != .plan {
            transitionFromPlanTo3D(
                preset: preset,
                bounds: bounds,
                aspect: aspect,
                viewSize: viewSize,
                reduceMotion: reduceMotion
            )
        } else if preset == .plan {
            transitionToPlan(viewSize: viewSize, reduceMotion: reduceMotion)
        } else {
            transitionBetween3D(
                preset: preset,
                bounds: bounds,
                aspect: aspect,
                reduceMotion: reduceMotion
            )
        }
    }

    private func transitionFromPlanTo3D(
        preset: ViewPreset,
        bounds: BoundingBox,
        aspect: Double,
        viewSize: CGSize,
        reduceMotion: Bool
    ) {
        let canvasCenterView = SIMD2<Double>(Double(viewSize.width / 2.0), Double(viewSize.height / 2.0))
        let centerWorld = transform.toWorld(canvasCenterView)
        let fovRad = 46.0 * .pi / 180.0
        let distance = (Double(viewSize.height) / transform.scale / 2.0) / tan(fovRad / 2.0)
        let initialPose = CameraPose(
            target: SIMD3<Double>(centerWorld.x, 0, centerWorld.y),
            azimuth: CameraRig.planAzimuth,
            polar: CameraRig.minPolar,
            distance: distance,
            fieldOfViewDegrees: 46.0
        )
        cameraRig = CameraRig(pose: initialPose)
        viewPreset = preset

        if preset == .eye {
            enterEyeView(in: bounds)
        } else {
            let targetPose = CameraRig.pose(for: preset, framing: bounds, aspect: aspect)
            cameraRig.transition(to: targetPose, animated: !reduceMotion)
        }
        rebuildSceneGeometry()
    }

    private func transitionToPlan(viewSize: CGSize, reduceMotion: Bool) {
        let targetPose = CameraPose(
            target: cameraRig.pose.target,
            azimuth: CameraRig.planAzimuth,
            polar: CameraRig.minPolar,
            distance: cameraRig.pose.distance,
            fieldOfViewDegrees: 46.0
        )
        cameraRig.setEye(nil)
        if reduceMotion {
            cameraRig.transition(to: targetPose, animated: false)
            applyCameraToCanvas(viewSize: viewSize)
            viewPreset = .plan
        } else {
            isTransitioningToPlan = true
            cameraRig.transition(to: targetPose, animated: true)
        }
    }

    private func transitionBetween3D(
        preset: ViewPreset,
        bounds: BoundingBox,
        aspect: Double,
        reduceMotion: Bool
    ) {
        viewPreset = preset
        if preset == .eye {
            enterEyeView(in: bounds)
        } else {
            cameraRig.setEye(nil)
            let targetPose = CameraRig.pose(for: preset, framing: bounds, aspect: aspect)
            cameraRig.transition(to: targetPose, animated: !reduceMotion)
        }
    }

    func advanceCamera(by seconds: Double, viewSize: CGSize) {
        let stillAnimating = cameraRig.advance(by: seconds)
        if !stillAnimating && isTransitioningToPlan {
            isTransitioningToPlan = false
            applyCameraToCanvas(viewSize: viewSize)
            viewPreset = .plan
        }
    }

    private func applyCameraToCanvas(viewSize: CGSize) {
        let fovRad = 46.0 * .pi / 180.0
        let scale = (Double(viewSize.height) / 2.0) / (cameraRig.pose.distance * tan(fovRad / 2.0))
        let worldCenter = SIMD2<Double>(cameraRig.pose.target.x, cameraRig.pose.target.z)
        let canvasCenter = SIMD2<Double>(Double(viewSize.width / 2.0), Double(viewSize.height / 2.0))
        let offset = canvasCenter - worldCenter * scale
        transform = CanvasTransform(scale: scale, offset: offset)
    }

    func rebuildSceneGeometryDebounced() {
        guard viewPreset != .plan else { return }
        sceneRebuildTask?.cancel()
        sceneRebuildTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self?.rebuildSceneGeometry()
        }
    }

    func rebuildSceneGeometry() {
        guard let layout = layoutWithInspectorDraft else { return }
        sceneGeometryGeneration += 1
        let generation = sceneGeometryGeneration
        let currentLegend = legend
        let currentTab = tab.objectTab
        Task.detached(priority: .userInitiated) { [weak self] in
            var geometry = SceneGeometryBuilder.build(layout: layout, legend: currentLegend, tab: currentTab)
            geometry.version = generation
            await MainActor.run {
                guard let self, generation == self.sceneGeometryGeneration else { return }
                self.sceneGeometry = geometry
            }
        }
    }

    func handle3DOrbit(delta: CGSize) {
        cameraRig.orbit(deltaX: Double(delta.width), deltaY: Double(delta.height))
    }

    func handle3DPan(delta: CGSize, viewHeight: Double) {
        cameraRig.pan(deltaX: Double(delta.width), deltaY: Double(delta.height), viewHeight: viewHeight)
    }

    func handle3DZoom(delta: Double, isPrecise: Bool, viewPoint: CGPoint, viewSize: CGSize) {
        guard cameraRig.eye == nil else { return }
        let floorPoint = CameraRay.floorPoint(
            viewPoint: SIMD2(Double(viewPoint.x), Double(viewPoint.y)),
            viewSize: SIMD2(Double(viewSize.width), Double(viewSize.height)),
            cameraPosition: cameraRig.cameraPosition,
            lookAt: cameraRig.lookAtPoint,
            fieldOfViewDegrees: cameraRig.activeFieldOfViewDegrees
        )
        let base = isPrecise ? CanvasTransform.preciseScrollZoomBase : CanvasTransform.lineScrollZoomBase
        let clampedDelta = isPrecise ? delta : min(max(delta, -10), 10)
        cameraRig.zoom(byFactor: pow(base, clampedDelta), toward: floorPoint)
    }

    func handle3DLook(delta: CGSize) {
        cameraRig.eyeLook(deltaX: Double(delta.width), deltaY: Double(delta.height))
    }

    /// The spawn marker usually sits in the lobby, so walking is bounded by the hall and lobby together.
    private var walkableBounds: BoundingBox {
        activeLayout.map { LayoutGeometry.bounds(of: $0.hall + $0.lobby) }
            ?? BoundingBox(minX: 0, maxX: 40, minY: 0, maxY: 30)
    }

    func handle3DWalk(forward: Double, right: Double) {
        cameraRig.eyeWalk(forward: forward, right: right, in: walkableBounds)
    }

    func enterEyeView(in bounds: BoundingBox) {
        let hallCenter = SIMD2<Double>((bounds.minX + bounds.maxX) / 2.0, (bounds.minY + bounds.maxY) / 2.0)
        let walkable = walkableBounds
        let spawnPos = activeLayout?.markers.first(where: { $0.kind == .spawn })?.position
            ?? SIMD2<Double>((walkable.minX + walkable.maxX) / 2.0, walkable.maxY - 2.0)
        let eyePos = SIMD3<Double>(spawnPos.x, 1.6, spawnPos.y)

        let toCenterX = hallCenter.x - spawnPos.x
        let toCenterZ = hallCenter.y - spawnPos.y
        let yaw = atan2(-toCenterX, -toCenterZ)

        cameraRig.setEye(EyePose(position: eyePos, yaw: yaw, pitch: 0))
    }

    func handle3DClick(viewPoint: CGPoint, viewSize: CGSize) {
        let floorPoint = CameraRay.floorPoint(
            viewPoint: SIMD2(Double(viewPoint.x), Double(viewPoint.y)),
            viewSize: SIMD2(Double(viewSize.width), Double(viewSize.height)),
            cameraPosition: cameraRig.cameraPosition,
            lookAt: cameraRig.lookAtPoint,
            fieldOfViewDegrees: cameraRig.activeFieldOfViewDegrees
        )
        guard let floorPoint, let layout = activeLayout else {
            selectObject(nil)
            return
        }
        let hitID = LayoutHitTester.object(at: floorPoint, in: layout, tab: tab)
        selectObject(hitID)
    }

    var selectionOutlineBoxes: [BoundingBox3D] {
        guard let layout = activeLayout else { return [] }
        if let groupSelection {
            var members: [LayoutObject] = []
            for object in layout.objects where groupSelection.memberIDs.contains(object.id) {
                members.append(object)
            }
            return members.map(boundingBox3D(for:))
        }
        guard let selectionID, let object = layout.objects.first(where: { $0.id == selectionID }) else {
            return []
        }
        return [boundingBox3D(for: object)]
    }

    private func boundingBox3D(for object: LayoutObject) -> BoundingBox3D {
        let height = object.heightM
            ?? (object.kind == .booth ? BoothShape.panelHeightM : (object.kind == .wall ? 3.0 : 1.0))
        return BoundingBox3D(
            center: SIMD3<Double>(object.placement.center.x, height / 2.0, object.placement.center.y),
            size: SIMD3<Double>(object.placement.sizeM.x, height, object.placement.sizeM.y),
            yaw: object.placement.rotationRadians
        )
    }
}

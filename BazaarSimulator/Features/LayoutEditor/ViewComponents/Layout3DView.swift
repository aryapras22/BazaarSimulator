import AppKit
import RealityKit
import SwiftUI

struct Layout3DView: View {
    let geometry: SceneGeometry?
    let pose: CameraPose
    let eye: EyePose?
    let selectionOutline: [BoundingBox3D]
    var onOrbit: (CGSize) -> Void
    var onPan: (CGSize) -> Void
    var onZoom: (Double, CGPoint) -> Void
    var onLook: (CGSize) -> Void
    var onWalk: (Double, Double) -> Void
    var onClick: (CGPoint, CGSize) -> Void
    var onFrame: (Double) -> Void

    @State private var holder = SceneHolder()
    @State private var lastDragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            RealityView { content in
                holder.onFrame = onFrame
                holder.install(in: &content)
            } update: { _ in
                holder.onFrame = onFrame
                holder.update(geometry: geometry, pose: pose, eye: eye, outlines: selectionOutline)
            }
            .realityViewCameraControls(.none)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let delta = CGSize(
                            width: value.translation.width - lastDragTranslation.width,
                            height: value.translation.height - lastDragTranslation.height
                        )
                        lastDragTranslation = value.translation
                        if eye != nil {
                            onLook(delta)
                        } else if NSEvent.modifierFlags.contains(.shift) {
                            onPan(delta)
                        } else {
                            onOrbit(delta)
                        }
                    }
                    .onEnded { _ in
                        lastDragTranslation = .zero
                    }
            )
            .overlay {
                CanvasScrollCatcher { delta, location, isPrecise, isCommand in
                    if isPrecise && !isCommand {
                        onPan(CGSize(width: delta.width, height: delta.height))
                    } else {
                        onZoom(Double(delta.height * 10.0), location)
                    }
                }
            }
            .onTapGesture { point in
                onClick(point, proxy.size)
            }
            .onKeyPress(.upArrow, phases: .down) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(step, 0.0)
                return .handled
            }
            .onKeyPress(.downArrow, phases: .down) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(-step, 0.0)
                return .handled
            }
            .onKeyPress(.leftArrow, phases: .down) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(0.0, -step)
                return .handled
            }
            .onKeyPress(.rightArrow, phases: .down) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(0.0, step)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "wW")) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(step, 0.0)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(-step, 0.0)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "aA")) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(0.0, -step)
                return .handled
            }
            .onKeyPress(characters: CharacterSet(charactersIn: "dD")) { press in
                let step = press.modifiers.contains(.shift) ? 2.0 : 0.5
                onWalk(0.0, step)
                return .handled
            }
            .focusable()
        }
    }
}

@MainActor
final class SceneHolder {
    var onFrame: ((Double) -> Void)?

    private let rootEntity = Entity()
    private let cameraEntity = PerspectiveCamera()
    private let lightEntity = DirectionalLight()
    private let staticRoot = Entity()
    private let outlineRoot = Entity()

    private var lastGeometryVersion: Int = -1
    private var lastOutlines: [BoundingBox3D] = []
    private var updateSubscription: EventSubscription?

    func install(in content: inout RealityViewCameraContent) {
        content.camera = .virtual
        cameraEntity.camera.fieldOfViewInDegrees = 46
        content.cameraTarget = cameraEntity
        content.add(rootEntity)
        rootEntity.addChild(cameraEntity)
        rootEntity.addChild(lightEntity)
        rootEntity.addChild(staticRoot)
        rootEntity.addChild(outlineRoot)

        lightEntity.look(at: .zero, from: SIMD3<Float>(20, 40, 10), relativeTo: nil)

        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.onFrame?(event.deltaTime)
        }
    }

    func update(
        geometry: SceneGeometry?,
        pose: CameraPose,
        eye: EyePose?,
        outlines: [BoundingBox3D]
    ) {
        updateCamera(pose: pose, eye: eye)
        updateGeometry(geometry)
        updateOutlines(outlines)
    }

    private func updateCamera(pose: CameraPose, eye: EyePose?) {
        if let eye {
            cameraEntity.camera.fieldOfViewInDegrees = Float(CameraRig.eyeFieldOfViewDegrees)
            let eyePos = SIMD3<Float>(eye.position)
            cameraEntity.position = eyePos
            let lookAt = CameraRig(pose: pose, eye: eye).lookAtPoint
            cameraEntity.look(at: SIMD3<Float>(lookAt), from: eyePos, relativeTo: nil)
        } else {
            cameraEntity.camera.fieldOfViewInDegrees = Float(pose.fieldOfViewDegrees)
            let target = SIMD3<Float>(Float(pose.target.x), Float(pose.target.y), Float(pose.target.z))
            let cosAz = cos(pose.azimuth)
            let sinAz = sin(pose.azimuth)
            let cosPol = cos(pose.polar)
            let sinPol = sin(pose.polar)
            let sphericalOffset = SIMD3<Float>(
                Float(cosAz * sinPol * pose.distance),
                Float(cosPol * pose.distance),
                Float(sinAz * sinPol * pose.distance)
            )
            let camPos = target + sphericalOffset
            cameraEntity.position = camPos
            cameraEntity.look(at: target, from: camPos, relativeTo: nil)
        }
    }

    private func updateGeometry(_ geometry: SceneGeometry?) {
        guard let geometry else {
            staticRoot.children.removeAll()
            lastGeometryVersion = -1
            return
        }
        guard geometry.version != lastGeometryVersion else { return }
        do {
            let entities = try SceneMeshFactory.entities(for: geometry)
            staticRoot.children.removeAll()
            for entity in entities {
                staticRoot.addChild(entity)
            }
            lastGeometryVersion = geometry.version
        } catch {
            assertionFailure("Scene mesh build failed: \(error)")
        }
    }

    private func updateOutlines(_ outlines: [BoundingBox3D]) {
        guard outlines != lastOutlines else { return }
        lastOutlines = outlines
        outlineRoot.children.removeAll()
        do {
            if let outlineEntity = try SceneMeshFactory.outlineEntity(for: outlines) {
                outlineRoot.addChild(outlineEntity)
            }
        } catch {
            // Ignore failure
        }
    }
}

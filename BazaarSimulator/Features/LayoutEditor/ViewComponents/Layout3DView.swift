import AppKit
import RealityKit
import SwiftUI

struct Layout3DView: View {
    let geometry: SceneGeometry?
    let pose: CameraPose
    let selectionOutline: [BoundingBox3D]
    var onOrbit: (CGSize) -> Void
    var onPan: (CGSize) -> Void
    var onZoom: (_ deltaY: Double, _ isPrecise: Bool, _ location: CGPoint) -> Void
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
                holder.update(geometry: geometry, pose: pose, outlines: selectionOutline)
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
                        if NSEvent.modifierFlags.contains(.shift) {
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
                        onZoom(Double(delta.height), isPrecise, location)
                    }
                }
            }
            .onTapGesture { point in
                onClick(point, proxy.size)
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
        outlines: [BoundingBox3D]
    ) {
        updateCamera(pose: pose)
        updateGeometry(geometry)
        updateOutlines(outlines)
    }

    private func updateCamera(pose: CameraPose) {
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

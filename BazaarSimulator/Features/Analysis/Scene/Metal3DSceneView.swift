import MetalKit
import SwiftUI

/// The 3D simulator on screen. Drag to orbit, scroll or pinch to zoom, shift-drag to move.
struct Metal3DSceneView: NSViewRepresentable {
    let venue: SimulationVenue
    let frame: SimulationSceneFrame

    func makeCoordinator() -> Coordinator {
        Coordinator(venue: venue)
    }

    func makeNSView(context: Context) -> OrbitView {
        let coordinator = context.coordinator
        let view = OrbitView(frame: .zero, device: coordinator.renderer?.device)
        view.delegate = coordinator
        view.colorPixelFormat = Metal3DRenderer.colorFormat
        view.clearColor = Metal3DRenderer.background
        view.framebufferOnly = true
        // The view redraws when SwiftUI hands it a new frame or the camera moves, so a paused simulation
        // costs nothing.
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.onOrbit = { [weak view] dx, dy in
            coordinator.camera.orbit(dx: dx, dy: dy)
            view?.setNeedsDisplay(view?.bounds ?? .zero)
        }
        view.onPan = { [weak view] dx, dy in
            coordinator.camera.pan(dx: dx, dy: dy)
            view?.setNeedsDisplay(view?.bounds ?? .zero)
        }
        view.onZoom = { [weak view] amount in
            coordinator.camera.zoom(amount)
            view?.setNeedsDisplay(view?.bounds ?? .zero)
        }
        return view
    }

    func updateNSView(_ view: OrbitView, context: Context) {
        context.coordinator.update(venue: venue, frame: frame)
        view.setNeedsDisplay(view.bounds)
    }

    /// A Metal view that turns mouse and trackpad input into camera moves:
    /// - Left-click drag: Orbit (rotate yaw and tilt pitch)
    /// - Right-click drag, middle-click drag, Shift/Option-drag, or 2-finger trackpad scroll: Pan across the floor
    /// - Pinch to zoom, mouse scroll wheel, or Option/Command + 2-finger scroll: Zoom in/out
    /// - 2-finger trackpad twist: Rotate yaw
    final class OrbitView: MTKView {
        var onOrbit: (Float, Float) -> Void = { _, _ in }
        var onPan: (Float, Float) -> Void = { _, _ in }
        var onZoom: (Float) -> Void = { _ in }

        override var acceptsFirstResponder: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func mouseDragged(with event: NSEvent) {
            let dx = Float(event.deltaX)
            let dy = Float(event.deltaY)
            if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option) {
                onPan(dx, dy)
            } else {
                onOrbit(dx, dy)
            }
        }

        override func rightMouseDragged(with event: NSEvent) {
            onPan(Float(event.deltaX), Float(event.deltaY))
        }

        override func otherMouseDragged(with event: NSEvent) {
            onPan(Float(event.deltaX), Float(event.deltaY))
        }

        override func scrollWheel(with event: NSEvent) {
            if event.hasPreciseScrollingDeltas {
                if event.modifierFlags.contains(.option) || event.modifierFlags.contains(.command) {
                    onZoom(Float(event.scrollingDeltaY) * 0.35)
                } else {
                    onPan(Float(event.scrollingDeltaX) * 0.65, Float(event.scrollingDeltaY) * 0.65)
                }
            } else {
                onZoom(Float(event.scrollingDeltaY) * 2.5)
            }
        }

        override func magnify(with event: NSEvent) {
            onZoom(Float(event.magnification) * 85)
        }

        override func rotate(with event: NSEvent) {
            onOrbit(Float(event.rotation) * 2.2, 0)
        }
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let renderer = Metal3DRenderer(sampleCount: 4) ?? Metal3DRenderer(sampleCount: 1)
        var camera: OrbitCamera
        private var venue: SimulationVenue
        private var frame = SimulationSceneFrame()

        init(venue: SimulationVenue) {
            self.venue = venue
            camera = .framing(plan: venue.plan)
        }

        /// A different venue starts with the camera framed on it.
        func update(venue: SimulationVenue, frame: SimulationSceneFrame) {
            if venue.id != self.venue.id {
                camera = .framing(plan: venue.plan)
            }
            self.venue = venue
            self.frame = frame
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer, let drawable = view.currentDrawable else { return }
            renderer.render(frame, venue: venue, camera: camera, to: drawable.texture, present: drawable)
        }
    }
}

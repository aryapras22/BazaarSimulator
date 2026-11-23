import MetalKit
import SwiftUI

/// The 3D simulator on screen. Drag to orbit, scroll or pinch to zoom, shift-drag to move.
struct Metal3DSceneView: NSViewRepresentable {
    let venue: SimulationVenue
    let frame: SimulationSceneFrame
    var backgroundColor: Color?
    var initialDistanceScale: Float = 1.0
    var zoomRequest: CameraZoomRequest?

    private var resolvedClearColor: MTLClearColor {
        backgroundColor.map(Metal3DRenderer.clearColor(for:)) ?? Metal3DRenderer.background
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            venue: venue,
            clearColor: resolvedClearColor,
            initialDistanceScale: initialDistanceScale,
            lastZoomRequestID: zoomRequest?.id
        )
    }

    func makeNSView(context: Context) -> OrbitView {
        let coordinator = context.coordinator
        let view = OrbitView(frame: .zero, device: coordinator.renderer?.device)
        view.delegate = coordinator
        view.colorPixelFormat = Metal3DRenderer.colorFormat
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = resolvedClearColor
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
        let clearColor = resolvedClearColor
        view.clearColor = clearColor
        context.coordinator.update(
            venue: venue,
            frame: frame,
            clearColor: clearColor,
            initialDistanceScale: initialDistanceScale,
            zoomRequest: zoomRequest
        )
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
        private var clearColor: MTLClearColor
        private var initialDistanceScale: Float
        private var lastZoomRequestID: Int?

        init(
            venue: SimulationVenue,
            clearColor: MTLClearColor = Metal3DRenderer.background,
            initialDistanceScale: Float = 1.0,
            lastZoomRequestID: Int? = nil
        ) {
            self.venue = venue
            self.clearColor = clearColor
            self.initialDistanceScale = initialDistanceScale
            self.lastZoomRequestID = lastZoomRequestID
            camera = .framing(plan: venue.plan, distanceScale: initialDistanceScale)
        }

        /// A different venue starts with the camera framed on it.
        func update(
            venue: SimulationVenue,
            frame: SimulationSceneFrame,
            clearColor: MTLClearColor,
            initialDistanceScale: Float,
            zoomRequest: CameraZoomRequest?
        ) {
            if venue.id != self.venue.id || initialDistanceScale != self.initialDistanceScale {
                self.initialDistanceScale = initialDistanceScale
                camera = .framing(plan: venue.plan, distanceScale: initialDistanceScale)
            }
            if let zoomRequest, lastZoomRequestID != zoomRequest.id {
                lastZoomRequestID = zoomRequest.id
                let amount: Float = zoomRequest.direction == .zoomIn ? 24 : -24
                camera.zoom(amount)
            }
            self.venue = venue
            self.frame = frame
            self.clearColor = clearColor
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let renderer, let drawable = view.currentDrawable else { return }
            renderer.render(
                frame, venue: venue, camera: camera, to: drawable.texture, present: drawable, clearColor: clearColor
            )
        }
    }
}

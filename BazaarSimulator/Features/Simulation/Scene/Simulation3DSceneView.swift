import AppKit
import SceneKit
import SwiftUI

/// A SwiftUI NSViewRepresentable wrapper around SceneKit's SCNView.
/// Supports native macOS trackpad orbit (drag), pan (two-finger/shift-drag), and zoom (scroll/pinch).
struct Simulation3DSceneView: NSViewRepresentable {
    let layout: Layout

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.14, alpha: 1.0)
        scnView.scene = VenueSceneBuilder.buildScene(from: layout)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.antialiasingMode = .multisampling4X
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true

        context.coordinator.lastLayoutID = layout.id
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        // Rebuild scene only if layout changed
        if context.coordinator.lastLayoutID != layout.id {
            context.coordinator.lastLayoutID = layout.id
            scnView.scene = VenueSceneBuilder.buildScene(from: layout)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastLayoutID: UUID?
    }
}

import AppKit
import SceneKit
import SwiftUI

/// A SwiftUI NSViewRepresentable wrapper around SceneKit's SCNView.
/// Supports native macOS trackpad orbit (drag), pan (two-finger/shift-drag), and zoom (scroll/pinch),
/// and updates 3D visitor nodes and optional density heatmap cells every tick.
struct Simulation3DSceneView: NSViewRepresentable {
    let layout: Layout
    var visitors: [SimulatedVisitor] = []
    var densityCells: [DensityCell] = []
    var showHeatmap = false

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
        // Rebuild base scene if the layout changed
        if context.coordinator.lastLayoutID != layout.id {
            context.coordinator.lastLayoutID = layout.id
            scnView.scene = VenueSceneBuilder.buildScene(from: layout)
            context.coordinator.visitorNodes.removeAll()
            context.coordinator.heatmapNodes.removeAll()
        }

        guard let rootNode = scnView.scene?.rootNode else { return }
        updateVisitorNodes(in: rootNode, coordinator: context.coordinator)
        updateHeatmapNodes(in: rootNode, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastLayoutID: UUID?
        var visitorNodes: [Int: SCNNode] = [:]
        var heatmapNodes: [Int: SCNNode] = [:]
    }

    // MARK: - Visitor Node Updates

    private func updateVisitorNodes(in rootNode: SCNNode, coordinator: Coordinator) {
        let activeIDs = Set(visitors.map(\.id))

        // Remove nodes for visitors who have left the venue
        for (id, node) in coordinator.visitorNodes where !activeIDs.contains(id) {
            node.removeFromParentNode()
            coordinator.visitorNodes.removeValue(forKey: id)
        }

        // Create or update nodes for active visitors
        for visitor in visitors {
            let node: SCNNode
            if let existing = coordinator.visitorNodes[visitor.id] {
                node = existing
            } else {
                let created = makeVisitorNode(for: visitor)
                rootNode.addChildNode(created)
                coordinator.visitorNodes[visitor.id] = created
                node = created
            }

            node.position = SCNVector3(
                CGFloat(visitor.position.x),
                0.65,
                CGFloat(visitor.position.y)
            )
            node.geometry?.firstMaterial?.diffuse.contents = color(for: visitor.state)
        }
    }

    private func makeVisitorNode(for visitor: SimulatedVisitor) -> SCNNode {
        let capsule = SCNCapsule(capRadius: 0.22, height: 1.3)
        let material = SCNMaterial()
        material.diffuse.contents = color(for: visitor.state)
        material.lightingModel = .lambert
        capsule.materials = [material]

        let node = SCNNode(geometry: capsule)
        node.name = "visitor-\(visitor.id)"
        return node
    }

    private func color(for state: VisitorState) -> NSColor {
        switch state {
        case .walking:
            return NSColor.systemBlue
        case .queueing:
            return NSColor.systemOrange
        case .browsing:
            return NSColor.systemPurple
        case .exiting:
            return NSColor.systemGreen
        }
    }

    // MARK: - Heatmap Overlay Updates

    private func updateHeatmapNodes(in rootNode: SCNNode, coordinator: Coordinator) {
        if !showHeatmap {
            for (_, node) in coordinator.heatmapNodes {
                node.removeFromParentNode()
            }
            coordinator.heatmapNodes.removeAll()
            return
        }

        let activeCellIDs = Set(densityCells.map(\.id))
        for (id, node) in coordinator.heatmapNodes where !activeCellIDs.contains(id) {
            node.removeFromParentNode()
            coordinator.heatmapNodes.removeValue(forKey: id)
        }

        for cell in densityCells {
            let node: SCNNode
            if let existing = coordinator.heatmapNodes[cell.id] {
                node = existing
            } else {
                let tile = SCNBox(width: 1.9, height: 0.04, length: 1.9, chamferRadius: 0.05)
                let material = SCNMaterial()
                material.lightingModel = .constant
                tile.materials = [material]

                let created = SCNNode(geometry: tile)
                created.name = "heatmap-\(cell.id)"
                rootNode.addChildNode(created)
                coordinator.heatmapNodes[cell.id] = created
                node = created
            }

            node.position = SCNVector3(CGFloat(cell.center.x), 0.03, CGFloat(cell.center.y))
            node.geometry?.firstMaterial?.diffuse.contents = heatmapColor(
                density: cell.peoplePerSquareMetre
            )
        }
    }

    private func heatmapColor(density: Double) -> NSColor {
        if density >= 1.5 {
            return NSColor.systemRed.withAlphaComponent(0.55)
        } else if density >= 0.75 {
            return NSColor.systemOrange.withAlphaComponent(0.45)
        } else {
            return NSColor.systemGreen.withAlphaComponent(0.35)
        }
    }
}

import AppKit
import CoreGraphics
import SceneKit
import SwiftUI

/// A SwiftUI NSViewRepresentable wrapper around SceneKit's SCNView.
/// Supports native macOS trackpad orbit (drag), pan (two-finger/shift-drag), and zoom (scroll/pinch),
/// and renders 3D visitor capsules plus a smooth 10x10-per-m² floor heatmap overlay.
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
        if context.coordinator.lastLayoutID != layout.id {
            context.coordinator.lastLayoutID = layout.id
            scnView.scene = VenueSceneBuilder.buildScene(from: layout)
            context.coordinator.visitorNodes.removeAll()
            context.coordinator.heatmapPlaneNode = nil
        }

        guard let rootNode = scnView.scene?.rootNode else { return }
        updateVisitorNodes(in: rootNode, coordinator: context.coordinator)
        updateSmoothHeatmapOverlay(in: rootNode, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastLayoutID: UUID?
        var visitorNodes: [Int: SCNNode] = [:]
        var heatmapPlaneNode: SCNNode?
    }

    // MARK: - Visitor Node Updates

    private func updateVisitorNodes(in rootNode: SCNNode, coordinator: Coordinator) {
        let activeIDs = Set(visitors.map(\.id))

        for (id, node) in coordinator.visitorNodes where !activeIDs.contains(id) {
            node.removeFromParentNode()
            coordinator.visitorNodes.removeValue(forKey: id)
        }

        for visitor in visitors {
            let targetPos = SCNVector3(
                CGFloat(visitor.position.x),
                0.65,
                CGFloat(visitor.position.y)
            )
            if let existing = coordinator.visitorNodes[visitor.id] {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.055
                existing.position = targetPos
                SCNTransaction.commit()
                existing.geometry?.firstMaterial?.diffuse.contents = color(for: visitor.state)
            } else {
                let created = makeVisitorNode(for: visitor)
                created.position = targetPos
                rootNode.addChildNode(created)
                coordinator.visitorNodes[visitor.id] = created
            }
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

    // MARK: - Smooth 10x10 per m² Heatmap Plane

    private func updateSmoothHeatmapOverlay(in rootNode: SCNNode, coordinator: Coordinator) {
        if !showHeatmap || densityCells.isEmpty {
            coordinator.heatmapPlaneNode?.isHidden = true
            return
        }

        let planeNode: SCNNode
        if let existing = coordinator.heatmapPlaneNode {
            planeNode = existing
        } else {
            let created = makeHeatmapPlaneNode()
            rootNode.addChildNode(created)
            coordinator.heatmapPlaneNode = created
            planeNode = created
        }

        planeNode.isHidden = false
        if let image = renderSmoothHeatmapImage(for: layout, cells: densityCells) {
            planeNode.geometry?.firstMaterial?.diffuse.contents = image
        }
    }

    private func makeHeatmapPlaneNode() -> SCNNode {
        let width = CGFloat(max(1.0, layout.sizeM.x))
        let length = CGFloat(max(1.0, layout.sizeM.y))
        let plane = SCNPlane(width: width, height: length)

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.diffuse.magnificationFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.mipFilter = .linear
        plane.materials = [material]

        let node = SCNNode(geometry: plane)
        node.name = "smooth-heatmap-plane"
        node.eulerAngles.x = -.pi / 2
        node.position = SCNVector3(width / 2, 0.03, length / 2)
        return node
    }

    /// Renders a smooth heatmap texture at 10x10 pixels per m² (0.1m resolution) with radial gradients.
    private func renderSmoothHeatmapImage(for layout: Layout, cells: [DensityCell]) -> NSImage? {
        let pixelsPerMetre = 10.0
        let texWidth = max(10, Int(ceil(layout.sizeM.x * pixelsPerMetre)))
        let texHeight = max(10, Int(ceil(layout.sizeM.y * pixelsPerMetre)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: texWidth,
            height: texHeight,
            bitsPerComponent: 8,
            bytesPerRow: texWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Flip Y so (0, 0) is at the top-left, matching SceneKit's XZ floor coordinates
        context.translateBy(x: 0, y: CGFloat(texHeight))
        context.scaleBy(x: 1, y: -1)

        let blobRadiusPx = CGFloat(1.65 * pixelsPerMetre)

        for cell in cells {
            let center = CGPoint(
                x: CGFloat(cell.center.x * pixelsPerMetre),
                y: CGFloat(cell.center.y * pixelsPerMetre)
            )
            let rgb = heatmapRGB(for: cell.peoplePerSquareMetre)
            let peakAlpha = CGFloat(min(0.78, max(0.18, cell.peoplePerSquareMetre / 1.15)))

            let colors = [
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha),
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: peakAlpha * 0.55),
                CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 0.0)
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.45, 1.0]

            if let gradient = CGGradient(
                colorsSpace: colorSpace,
                colors: colors,
                locations: locations
            ) {
                context.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: blobRadiusPx,
                    options: []
                )
            }
        }

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: texWidth, height: texHeight)
        )
    }

    private func heatmapRGB(for density: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        if density > 1.80 {
            return (0.85, 0.08, 0.22) // F: > 1.80
        } else if density >= 0.72 {
            return (1.0, 0.24, 0.20)  // E: 0.72 - 1.80
        } else if density >= 0.45 {
            return (1.0, 0.55, 0.12)  // D: 0.45 - 0.72
        } else if density >= 0.27 {
            return (0.98, 0.84, 0.18) // C: 0.27 - 0.45
        } else if density >= 0.08 {
            return (0.22, 0.86, 0.45) // B: 0.08 - 0.27
        } else {
            return (0.20, 0.78, 0.85) // A: < 0.08
        }
    }
}

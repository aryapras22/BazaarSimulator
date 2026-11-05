import AppKit
import Foundation
import SceneKit
import simd

/// Builds a 3D SceneKit scene from a 2D venue Layout.
/// Keeps things simple, readable, and easy to understand.
enum VenueSceneBuilder {

    // MARK: - Public API

    /// Builds the full 3D scene from the given Layout.
    static func buildScene(from layout: Layout) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.14, alpha: 1.0)

        let rootNode = scene.rootNode

        // 1. Add floors (hall and lobby)
        for floorNode in makeFloorNodes(for: layout) {
            rootNode.addChildNode(floorNode)
        }

        // 2. Add all venue objects (booths, tables, doors, walls, etc.)
        for object in layout.objects {
            if let objectNode = makeObjectNode(for: object) {
                rootNode.addChildNode(objectNode)
            }
        }

        // 3. Add lights
        for lightNode in makeLightingNodes(for: layout) {
            rootNode.addChildNode(lightNode)
        }

        // 4. Add camera
        let cameraNode = makeCameraNode(for: layout)
        rootNode.addChildNode(cameraNode)

        return scene
    }

    // MARK: - Floors

    private static func makeFloorNodes(for layout: Layout) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let floorColor = NSColor(calibratedRed: 0.11, green: 0.14, blue: 0.22, alpha: 1.0)
        let floorHeight: CGFloat = 0.1

        // If hall polygon has vertices, use its bounding box
        if layout.hall.count >= 3 {
            let minX = layout.hall.map(\.x).min() ?? 0
            let maxX = layout.hall.map(\.x).max() ?? layout.sizeM.x
            let minY = layout.hall.map(\.y).min() ?? 0
            let maxY = layout.hall.map(\.y).max() ?? layout.sizeM.y

            let width = CGFloat(maxX - minX)
            let length = CGFloat(maxY - minY)
            let centerX = CGFloat(minX + maxX) / 2
            let centerZ = CGFloat(minY + maxY) / 2

            let hallFloor = makeBoxNode(
                width: width,
                height: floorHeight,
                length: length,
                color: floorColor,
                position: SCNVector3(centerX, -floorHeight / 2, centerZ)
            )
            hallFloor.name = "hall-floor"
            nodes.append(hallFloor)
        } else {
            // Fallback to layout size
            let width = CGFloat(layout.sizeM.x)
            let length = CGFloat(layout.sizeM.y)
            let floor = makeBoxNode(
                width: width,
                height: floorHeight,
                length: length,
                color: floorColor,
                position: SCNVector3(width / 2, -floorHeight / 2, length / 2)
            )
            floor.name = "default-floor"
            nodes.append(floor)
        }

        // Lobby floor if present
        if layout.lobby.count >= 3 {
            let minX = layout.lobby.map(\.x).min() ?? 0
            let maxX = layout.lobby.map(\.x).max() ?? layout.sizeM.x
            let minY = layout.lobby.map(\.y).min() ?? 0
            let maxY = layout.lobby.map(\.y).max() ?? layout.sizeM.y

            let width = CGFloat(maxX - minX)
            let length = CGFloat(maxY - minY)
            let centerX = CGFloat(minX + maxX) / 2
            let centerZ = CGFloat(minY + maxY) / 2

            let lobbyColor = NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.18, alpha: 1.0)
            let lobbyFloor = makeBoxNode(
                width: width,
                height: floorHeight,
                length: length,
                color: lobbyColor,
                position: SCNVector3(centerX, -floorHeight / 2, centerZ)
            )
            lobbyFloor.name = "lobby-floor"
            nodes.append(lobbyFloor)
        }

        return nodes
    }

    // MARK: - Objects

    private static func makeObjectNode(for object: LayoutObject) -> SCNNode? {
        let width = CGFloat(object.placement.sizeM.x)
        let depth = CGFloat(object.placement.sizeM.y)
        let posX = CGFloat(object.placement.center.x)
        let posZ = CGFloat(object.placement.center.y)

        let node: SCNNode

        switch object.kind {
        case .booth:
            let height: CGFloat = 2.2
            let color = boothColor(for: object)
            node = makeBoxNode(
                width: width,
                height: height,
                length: depth,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .table:
            let height: CGFloat = 0.75
            let radius = min(width, depth) / 2
            let color = NSColor(calibratedRed: 0.82, green: 0.75, blue: 0.62, alpha: 1.0)
            node = makeCylinderNode(
                radius: radius,
                height: height,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .wall:
            let height: CGFloat = 2.8
            let color = NSColor(calibratedRed: 0.28, green: 0.32, blue: 0.40, alpha: 1.0)
            node = makeBoxNode(
                width: width,
                height: height,
                length: depth,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .door:
            let height: CGFloat = 0.04
            let color = doorColor(for: object)
            node = makeBoxNode(
                width: width,
                height: height,
                length: max(depth, 0.5),
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .pillar:
            let height: CGFloat = 3.5
            let radius = min(width, depth) / 2
            let color = NSColor(calibratedRed: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
            node = makeCylinderNode(
                radius: radius,
                height: height,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .stage:
            let height: CGFloat = 0.5
            let color = NSColor(calibratedRed: 0.52, green: 0.40, blue: 0.72, alpha: 1.0)
            node = makeBoxNode(
                width: width,
                height: height,
                length: depth,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )

        case .closedArea, .block, .fixture, .rail, .audienceArea:
            let height: CGFloat = 0.15
            let color = NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.30, alpha: 1.0)
            node = makeBoxNode(
                width: width,
                height: height,
                length: depth,
                color: color,
                position: SCNVector3(posX, height / 2, posZ)
            )
        }

        // Apply rotation around the vertical Y axis
        if object.placement.rotationRadians != 0 {
            node.eulerAngles.y = CGFloat(object.placement.rotationRadians)
        }

        node.name = "object-\(object.id)"
        return node
    }

    // MARK: - Color Helpers

    private static func boothColor(for object: LayoutObject) -> NSColor {
        let labelLower = object.label.lowercased()
        if labelLower.contains("food") || labelLower.contains("f&b") || labelLower.hasPrefix("f") {
            return NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.20, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.90, alpha: 1.0)
    }

    private static func doorColor(for object: LayoutObject) -> NSColor {
        switch object.doorFlow?.direction {
        case .entrance:
            return NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.45, alpha: 1.0) // Green
        case .exit:
            return NSColor(calibratedRed: 0.92, green: 0.30, blue: 0.30, alpha: 1.0) // Red
        default:
            return NSColor(calibratedRed: 0.35, green: 0.65, blue: 0.95, alpha: 1.0) // Blue (both)
        }
    }

    // MARK: - Lighting & Camera

    private static func makeLightingNodes(for layout: Layout) -> [SCNNode] {
        // 1. Soft ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(calibratedWhite: 0.55, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight

        // 2. Main directional light (sun/ceiling)
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = NSColor(calibratedWhite: 0.75, alpha: 1.0)
        directionalLight.castsShadow = true

        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        let midX = CGFloat(layout.sizeM.x / 2)
        let midZ = CGFloat(layout.sizeM.y / 2)
        directionalNode.position = SCNVector3(midX + 20, 40, midZ + 20)
        directionalNode.look(at: SCNVector3(midX, 0, midZ))

        return [ambientNode, directionalNode]
    }

    private static func makeCameraNode(for layout: Layout) -> SCNNode {
        let camera = SCNCamera()
        camera.zNear = 0.5
        camera.zFar = 500

        let cameraNode = SCNNode()
        cameraNode.camera = camera

        let midX = CGFloat(layout.sizeM.x / 2)
        let midZ = CGFloat(layout.sizeM.y / 2)
        let span = CGFloat(max(layout.sizeM.x, layout.sizeM.y))

        // Position camera back and up looking at the center
        cameraNode.position = SCNVector3(midX, span * 1.1, midZ + span * 0.9)
        cameraNode.look(at: SCNVector3(midX, 0, midZ))

        return cameraNode
    }

    // MARK: - Geometry Primitives

    private static func makeBoxNode(
        width: CGFloat,
        height: CGFloat,
        length: CGFloat,
        color: NSColor,
        position: SCNVector3
    ) -> SCNNode {
        let box = SCNBox(width: width, height: height, length: length, chamferRadius: 0.02)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        box.materials = [material]

        let node = SCNNode(geometry: box)
        node.position = position
        return node
    }

    private static func makeCylinderNode(
        radius: CGFloat,
        height: CGFloat,
        color: NSColor,
        position: SCNVector3
    ) -> SCNNode {
        let cylinder = SCNCylinder(radius: radius, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        cylinder.materials = [material]

        let node = SCNNode(geometry: cylinder)
        node.position = position
        return node
    }
}

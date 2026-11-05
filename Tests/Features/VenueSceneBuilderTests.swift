import SceneKit
import Testing
@testable import BazaarSimulator

@Suite("VenueSceneBuilder Tests")
struct VenueSceneBuilderTests {

    @Test("Builds scene with floor, camera, and lighting for a layout")
    func buildsBasicScene() {
        let layout = PreviewLayouts.smallMarket()
        let scene = VenueSceneBuilder.buildScene(from: layout)

        let root = scene.rootNode

        // Floor node should exist
        let floor = root.childNode(withName: "hall-floor", recursively: true)
        #expect(floor != nil)
        #expect(floor?.geometry is SCNBox)

        // Camera node should exist
        let cameras = root.childNodes.filter { $0.camera != nil }
        #expect(!cameras.isEmpty)

        // Lighting nodes should exist
        let lights = root.childNodes.filter { $0.light != nil }
        #expect(lights.count >= 2)
    }

    @Test("Creates 3D nodes for all layout objects")
    func createsNodesForObjects() {
        let layout = PreviewLayouts.smallMarket()
        let scene = VenueSceneBuilder.buildScene(from: layout)
        let root = scene.rootNode

        // Every object in layout.objects should produce a node with matching name
        for object in layout.objects {
            let nodeName = "object-\(object.id)"
            let node = root.childNode(withName: nodeName, recursively: true)
            #expect(node != nil, "Expected node for object \(object.label)")

            // Booths and walls should be boxes, tables and pillars should be cylinders
            if object.kind == .booth || object.kind == .wall {
                #expect(node?.geometry is SCNBox)
            } else if object.kind == .table || object.kind == .pillar {
                #expect(node?.geometry is SCNCylinder)
            }
        }
    }

    @Test("Builds large market scene (Beyond Market) successfully")
    func buildsLargeMarketScene() {
        let layout = PreviewLayouts.beyond()
        let scene = VenueSceneBuilder.buildScene(from: layout)
        let root = scene.rootNode

        // Beyond market has over 100 objects
        #expect(root.childNodes.count > 100)
    }
}

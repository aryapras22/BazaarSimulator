import AppKit
import RealityKit
import SwiftUI

@MainActor
enum SceneMeshFactory {
    static func entities(for geometry: SceneGeometry) throws -> [ModelEntity] {
        var result: [ModelEntity] = []
        for (key, mesh) in geometry.meshes {
            guard !mesh.positions.isEmpty, !mesh.indices.isEmpty else { continue }
            var descriptor = MeshDescriptor(name: key.role.rawValue)
            descriptor.positions = MeshBuffers.Positions(mesh.positions)
            descriptor.normals = MeshBuffers.Normals(mesh.normals)
            descriptor.primitives = .triangles(mesh.indices)
            let resource = try MeshResource.generate(from: [descriptor])
            let entity = ModelEntity(mesh: resource, materials: [material(for: key)])
            result.append(entity)
        }
        return result
    }

    static func material(for key: SceneMaterialKey) -> any RealityKit.Material {
        // A lit floor reads grey under the scene light, so it is unlit to stay white.
        if key.role == .floor && key.tint == nil {
            return UnlitMaterial(color: NSColor(Palette.sceneFloor))
        }
        if let tint = key.tint {
            let nsColor = NSColor(
                calibratedRed: CGFloat(tint.red),
                green: CGFloat(tint.green),
                blue: CGFloat(tint.blue),
                alpha: 1.0
            )
            return SimpleMaterial(color: nsColor, roughness: 0.8, isMetallic: false)
        }
        return SimpleMaterial(color: NSColor(color(for: key.role)), roughness: 0.8, isMetallic: false)
    }

    private static func color(for role: MaterialRole) -> Color {
        switch role {
        case .floor: return Palette.sceneFloor
        case .wall: return Palette.sceneWall
        case .panel, .fabric, .glass, .tabletop: return Palette.scenePanel
        case .counter, .fascia, .frame: return Palette.sceneCounter
        case .stage, .slab: return Palette.sceneSlab
        case .pillar: return Palette.scenePillar
        case .plant: return Palette.scenePlant
        case .sign: return Palette.sceneSign
        case .accent: return Palette.highlight
        }
    }

    static func outlineEntity(for boxes: [BoundingBox3D]) throws -> ModelEntity? {
        guard !boxes.isEmpty else { return nil }
        var mesh = TriangleMesh()
        let edgeThickness = 0.03

        for box in boxes {
            appendBoxEdges(box, thickness: edgeThickness, into: &mesh)
        }

        guard !mesh.positions.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "outline")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        descriptor.normals = MeshBuffers.Normals(mesh.normals)
        descriptor.primitives = .triangles(mesh.indices)
        let resource = try MeshResource.generate(from: [descriptor])
        let material = SimpleMaterial(color: NSColor(Palette.highlight), roughness: 0.5, isMetallic: false)
        return ModelEntity(mesh: resource, materials: [material])
    }

    private static func appendBoxEdges(
        _ box: BoundingBox3D,
        thickness: Double,
        into mesh: inout TriangleMesh
    ) {
        let halfW = box.size.x / 2.0
        let halfH = box.size.y / 2.0
        let halfD = box.size.z / 2.0

        // 4 vertical edges
        let corners: [(Double, Double)] = [(-halfW, -halfD), (halfW, -halfD), (halfW, halfD), (-halfW, halfD)]
        for (cornerX, cornerZ) in corners {
            mesh.appendBox(
                center: box.center + rotateY(SIMD3(cornerX, 0, cornerZ), yaw: box.yaw),
                size: SIMD3(thickness, box.size.y, thickness),
                yaw: box.yaw
            )
        }

        // 4 bottom edges
        appendHorizontalFrame(box, halfH: -halfH, thickness: thickness, into: &mesh)
        // 4 top edges
        appendHorizontalFrame(box, halfH: halfH, thickness: thickness, into: &mesh)
    }

    private static func appendHorizontalFrame(
        _ box: BoundingBox3D,
        halfH: Double,
        thickness: Double,
        into mesh: inout TriangleMesh
    ) {
        let halfW = box.size.x / 2.0
        let halfD = box.size.z / 2.0
        mesh.appendBox(
            center: box.center + rotateY(SIMD3(0, halfH, -halfD), yaw: box.yaw),
            size: SIMD3(box.size.x, thickness, thickness),
            yaw: box.yaw
        )
        mesh.appendBox(
            center: box.center + rotateY(SIMD3(0, halfH, halfD), yaw: box.yaw),
            size: SIMD3(box.size.x, thickness, thickness),
            yaw: box.yaw
        )
        mesh.appendBox(
            center: box.center + rotateY(SIMD3(-halfW, halfH, 0), yaw: box.yaw),
            size: SIMD3(thickness, thickness, box.size.z),
            yaw: box.yaw
        )
        mesh.appendBox(
            center: box.center + rotateY(SIMD3(halfW, halfH, 0), yaw: box.yaw),
            size: SIMD3(thickness, thickness, box.size.z),
            yaw: box.yaw
        )
    }

    private static func rotateY(_ vector: SIMD3<Double>, yaw: Double) -> SIMD3<Double> {
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        return SIMD3<Double>(
            vector.x * cosY - vector.z * sinY,
            vector.y,
            vector.x * sinY + vector.z * cosY
        )
    }
}

import Foundation
import simd

/// A shape the GPU can draw many times: corner positions with the direction each faces, and triangles.
struct MeshData {
    struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    var vertices: [Vertex] = []
    var indices: [UInt16] = []

    /// Adds a triangle, turned if needed so it faces the way its corners' normals point. Triangles that face
    /// outward are the ones the GPU draws.
    private mutating func addTriangle(_ a: UInt16, _ b: UInt16, _ c: UInt16) {
        let pa = vertices[Int(a)].position, pb = vertices[Int(b)].position, pc = vertices[Int(c)].position
        let facing = simd_cross(pb - pa, pc - pa)
        let wanted = vertices[Int(a)].normal + vertices[Int(b)].normal + vertices[Int(c)].normal
        if simd_dot(facing, wanted) >= 0 {
            indices += [a, b, c]
        } else {
            indices += [a, c, b]
        }
    }

    /// A box one unit on each side, centered on the origin.
    static let cube: MeshData = {
        var mesh = MeshData()
        let faces: [(normal: SIMD3<Float>, u: SIMD3<Float>, v: SIMD3<Float>)] = [
            (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)),
            (SIMD3(-1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 0)),
            (SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(1, 0, 0)),
            (SIMD3(0, -1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1)),
            (SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(0, 1, 0)),
            (SIMD3(0, 0, -1), SIMD3(0, 1, 0), SIMD3(1, 0, 0))
        ]
        for face in faces {
            let base = UInt16(mesh.vertices.count)
            for (a, b) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
                mesh.vertices.append(Vertex(position: (face.normal + face.u * a + face.v * b) * 0.5, normal: face.normal))
            }
            mesh.addTriangle(base, base + 1, base + 2)
            mesh.addTriangle(base, base + 2, base + 3)
        }
        return mesh
    }()

    /// A can one unit tall and one unit across, centered on the origin, standing on its end.
    static let cylinder: MeshData = {
        var mesh = MeshData()
        let segments = 28
        for index in 0..<segments {
            let first = Float(index) / Float(segments) * 2 * .pi
            let second = Float(index + 1) / Float(segments) * 2 * .pi
            let n0 = SIMD3<Float>(cos(first), 0, sin(first)), n1 = SIMD3<Float>(cos(second), 0, sin(second))
            let base = UInt16(mesh.vertices.count)
            mesh.vertices += [
                Vertex(position: n0 * 0.5 + SIMD3(0, -0.5, 0), normal: n0),
                Vertex(position: n1 * 0.5 + SIMD3(0, -0.5, 0), normal: n1),
                Vertex(position: n1 * 0.5 + SIMD3(0, 0.5, 0), normal: n1),
                Vertex(position: n0 * 0.5 + SIMD3(0, 0.5, 0), normal: n0)
            ]
            mesh.addTriangle(base, base + 1, base + 2)
            mesh.addTriangle(base, base + 2, base + 3)
            for (sign, height) in [(Float(1), Float(0.5)), (-1, -0.5)] {
                let cap = UInt16(mesh.vertices.count)
                let up = SIMD3<Float>(0, sign, 0)
                mesh.vertices += [
                    Vertex(position: SIMD3(0, height, 0), normal: up),
                    Vertex(position: n0 * 0.5 + SIMD3(0, height, 0), normal: up),
                    Vertex(position: n1 * 0.5 + SIMD3(0, height, 0), normal: up)
                ]
                mesh.addTriangle(cap, cap + 1, cap + 2)
            }
        }
        return mesh
    }()

    /// A standing figure: a can with rounded ends, `height` tall in total and `radius` across.
    static func capsule(radius: Float, height: Float) -> MeshData {
        var mesh = MeshData()
        let slices = 14
        let rings = 5
        let half = max(height / 2 - radius, 0)
        // From the bottom point, up the rounded end, along the side, and over the top.
        var rows: [(y: Float, ring: Float, lift: Float)] = []
        for step in 0...rings {
            let latitude = -Float.pi / 2 + Float(step) / Float(rings) * (Float.pi / 2)
            rows.append((-half + radius * sin(latitude), radius * cos(latitude), sin(latitude)))
        }
        for step in 0...rings {
            let latitude = Float(step) / Float(rings) * (Float.pi / 2)
            rows.append((half + radius * sin(latitude), radius * cos(latitude), sin(latitude)))
        }
        for row in rows {
            for slice in 0...slices {
                let angle = Float(slice) / Float(slices) * 2 * .pi
                let flat = SIMD3<Float>(cos(angle), 0, sin(angle))
                let normal = simd_normalize(flat * sqrt(max(1 - row.lift * row.lift, 0)) + SIMD3(0, row.lift, 0))
                mesh.vertices.append(Vertex(position: flat * row.ring + SIMD3(0, row.y, 0), normal: normal))
            }
        }
        let stride = UInt16(slices + 1)
        for row in 0..<(rows.count - 1) {
            for slice in 0..<slices {
                let a = UInt16(row) * stride + UInt16(slice)
                mesh.addTriangle(a, a + 1, a + stride)
                mesh.addTriangle(a + 1, a + stride + 1, a + stride)
            }
        }
        return mesh
    }
}

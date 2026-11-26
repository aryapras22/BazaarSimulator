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

    /// A pitched roof one unit on each side: a flat base, two slopes that meet in a ridge running along x, and
    /// a triangle closing each end. The slopes carry the normal of a low roof, so both read as facing up.
    static let wedge: MeshData = {
        var mesh = MeshData()
        func face(_ corners: [SIMD3<Float>], _ normal: SIMD3<Float>) {
            let base = UInt16(mesh.vertices.count)
            mesh.vertices += corners.map { Vertex(position: $0, normal: simd_normalize(normal)) }
            for index in 1..<(corners.count - 1) {
                mesh.addTriangle(base, base + UInt16(index), base + UInt16(index + 1))
            }
        }
        for side in [Float(-1), 1] {
            face(
                [SIMD3(-0.5, -0.5, side * 0.5), SIMD3(0.5, -0.5, side * 0.5), SIMD3(0.5, 0.5, 0), SIMD3(-0.5, 0.5, 0)],
                SIMD3(0, 1, side * 0.45)
            )
            face([SIMD3(side * 0.5, -0.5, -0.5), SIMD3(side * 0.5, -0.5, 0.5), SIMD3(side * 0.5, 0.5, 0)], SIMD3(side, 0, 0))
        }
        face(
            [SIMD3(-0.5, -0.5, -0.5), SIMD3(0.5, -0.5, -0.5), SIMD3(0.5, -0.5, 0.5), SIMD3(-0.5, -0.5, 0.5)], SIMD3(0, -1, 0)
        )
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

    /// A solid floor slab extruded downward from `topY` by `thickness`, matching a simple 2D polygon in XZ.
    static func floorSlab(polygon: [SIMD2<Float>], topY: Float, thickness: Float) -> MeshData {
        guard polygon.count >= 3 else { return MeshData() }
        let points2D = polygon.map { SIMD2<Double>(Double($0.x), Double($0.y)) }
        let triangles = PolygonTriangulator.triangulate(points2D)
        guard !triangles.isEmpty else { return MeshData() }

        let bottomY = topY - thickness
        var mesh = MeshData()
        mesh.appendCap(polygon: polygon, triangles: triangles, posY: topY, normalY: 1)
        mesh.appendCap(polygon: polygon, triangles: triangles, posY: bottomY, normalY: -1)
        mesh.appendRim(polygon: polygon, points2D: points2D, topY: topY, bottomY: bottomY)
        return mesh
    }

    private mutating func appendCap(
        polygon: [SIMD2<Float>],
        triangles: [(Int, Int, Int)],
        posY: Float,
        normalY: Float
    ) {
        let base = UInt16(vertices.count)
        let normal = SIMD3<Float>(0, normalY, 0)
        for point in polygon {
            vertices.append(Vertex(position: SIMD3(point.x, posY, point.y), normal: normal))
        }
        for (idxA, idxB, idxC) in triangles {
            addTriangle(base + UInt16(idxA), base + UInt16(idxB), base + UInt16(idxC))
        }
    }

    private mutating func appendRim(
        polygon: [SIMD2<Float>],
        points2D: [SIMD2<Double>],
        topY: Float,
        bottomY: Float
    ) {
        var doubleArea = 0.0
        for index in points2D.indices {
            let current = points2D[index]
            let next = points2D[(index + 1) % points2D.count]
            doubleArea += current.x * next.y - next.x * current.y
        }
        let outwardSign: Float = doubleArea >= 0 ? 1 : -1

        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let edge = end - start
            let length = simd_length(edge)
            guard length > 1e-6 else { continue }
            let outward2D = SIMD2<Float>(edge.y, -edge.x) * (outwardSign / length)
            let normal = SIMD3<Float>(outward2D.x, 0, outward2D.y)
            let base = UInt16(vertices.count)
            vertices += [
                Vertex(position: SIMD3(start.x, bottomY, start.y), normal: normal),
                Vertex(position: SIMD3(end.x, bottomY, end.y), normal: normal),
                Vertex(position: SIMD3(end.x, topY, end.y), normal: normal),
                Vertex(position: SIMD3(start.x, topY, start.y), normal: normal)
            ]
            addTriangle(base, base + 1, base + 2)
            addTriangle(base, base + 2, base + 3)
        }
    }
}

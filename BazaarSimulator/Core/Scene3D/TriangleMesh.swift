import Foundation
import simd

struct TriangleMesh: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []

    var triangleCount: Int { indices.count / 3 }

    mutating func append(_ other: TriangleMesh) {
        let baseIndex = UInt32(positions.count)
        positions.append(contentsOf: other.positions)
        normals.append(contentsOf: other.normals)
        indices.append(contentsOf: other.indices.map { $0 + baseIndex })
    }

    mutating func appendBox(center: SIMD3<Double>, size: SIMD3<Double>, yaw: Double = 0) {
        let halfW = size.x / 2.0
        let halfH = size.y / 2.0
        let halfD = size.z / 2.0

        appendBoxFace(
            corners: [
                SIMD3(-halfW, halfH, -halfD), SIMD3(-halfW, halfH, halfD),
                SIMD3(halfW, halfH, halfD), SIMD3(halfW, halfH, -halfD)
            ],
            normal: SIMD3(0, 1, 0), center: center, yaw: yaw
        )
        appendBoxFace(
            corners: [
                SIMD3(-halfW, -halfH, -halfD), SIMD3(halfW, -halfH, -halfD),
                SIMD3(halfW, -halfH, halfD), SIMD3(-halfW, -halfH, halfD)
            ],
            normal: SIMD3(0, -1, 0), center: center, yaw: yaw
        )
        appendBoxFace(
            corners: [
                SIMD3(-halfW, -halfH, halfD), SIMD3(halfW, -halfH, halfD),
                SIMD3(halfW, halfH, halfD), SIMD3(-halfW, halfH, halfD)
            ],
            normal: SIMD3(0, 0, 1), center: center, yaw: yaw
        )
        appendBoxFace(
            corners: [
                SIMD3(halfW, -halfH, -halfD), SIMD3(-halfW, -halfH, -halfD),
                SIMD3(-halfW, halfH, -halfD), SIMD3(halfW, halfH, -halfD)
            ],
            normal: SIMD3(0, 0, -1), center: center, yaw: yaw
        )
        appendBoxFace(
            corners: [
                SIMD3(halfW, -halfH, halfD), SIMD3(halfW, -halfH, -halfD),
                SIMD3(halfW, halfH, -halfD), SIMD3(halfW, halfH, halfD)
            ],
            normal: SIMD3(1, 0, 0), center: center, yaw: yaw
        )
        appendBoxFace(
            corners: [
                SIMD3(-halfW, -halfH, -halfD), SIMD3(-halfW, -halfH, halfD),
                SIMD3(-halfW, halfH, halfD), SIMD3(-halfW, halfH, -halfD)
            ],
            normal: SIMD3(-1, 0, 0), center: center, yaw: yaw
        )
    }

    private mutating func appendBoxFace(
        corners: [SIMD3<Double>],
        normal: SIMD3<Double>,
        center: SIMD3<Double>,
        yaw: Double
    ) {
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        let baseIndex = UInt32(positions.count)
        let normalVec = SIMD3<Float>(
            Float(normal.x * cosY - normal.z * sinY),
            Float(normal.y),
            Float(normal.x * sinY + normal.z * cosY)
        )
        for corner in corners {
            let worldX = center.x + corner.x * cosY - corner.z * sinY
            let worldY = center.y + corner.y
            let worldZ = center.z + corner.x * sinY + corner.z * cosY
            positions.append(SIMD3<Float>(Float(worldX), Float(worldY), Float(worldZ)))
            normals.append(normalVec)
        }
        indices.append(contentsOf: [
            baseIndex, baseIndex + 1, baseIndex + 2,
            baseIndex, baseIndex + 2, baseIndex + 3
        ])
    }
}

extension TriangleMesh {
    /// An upright cylinder with an oval cross-section, `radii` along its own x and z, turned by `yaw` about +y.
    mutating func appendCylinder(
        center: SIMD3<Double>,
        radii: SIMD2<Double>,
        height: Double,
        yaw: Double = 0,
        segments: Int = 16
    ) {
        let segCount = max(segments, 4)
        let bottomY = center.y - height / 2.0
        let topY = center.y + height / 2.0
        let rim = (0..<segCount).map { index in
            Self.ovalRimPoint(angle: 2.0 * Double.pi * Double(index) / Double(segCount), radii: radii, yaw: yaw)
        }

        for index in 0..<segCount {
            let first = rim[index]
            let second = rim[(index + 1) % segCount]
            let baseIndex = UInt32(positions.count)
            for (point, posY) in [(first, bottomY), (second, bottomY), (second, topY), (first, topY)] {
                let position = SIMD3<Double>(center.x + point.offset.x, posY, center.z + point.offset.y)
                positions.append(SIMD3<Float>(position))
            }
            for normal in [first.normal, second.normal, second.normal, first.normal] {
                normals.append(SIMD3<Float>(Float(normal.x), 0, Float(normal.y)))
            }
            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex, baseIndex + 2, baseIndex + 3
            ])
        }

        appendCap(center: center, rim: rim.map(\.offset), posY: topY, facesUp: true)
        appendCap(center: center, rim: rim.map(\.offset), posY: bottomY, facesUp: false)
    }

    private static func ovalRimPoint(
        angle: Double,
        radii: SIMD2<Double>,
        yaw: Double
    ) -> (offset: SIMD2<Double>, normal: SIMD2<Double>) {
        let local = SIMD2<Double>(radii.x * cos(angle), radii.y * sin(angle))
        let gradient = SIMD2<Double>(cos(angle) / max(radii.x, 1e-6), sin(angle) / max(radii.y, 1e-6))
        let localNormal = simd_normalize(gradient)
        let turn = { (vector: SIMD2<Double>) in
            SIMD2<Double>(vector.x * cos(yaw) - vector.y * sin(yaw), vector.x * sin(yaw) + vector.y * cos(yaw))
        }
        return (turn(local), turn(localNormal))
    }

    private mutating func appendCap(center: SIMD3<Double>, rim: [SIMD2<Double>], posY: Double, facesUp: Bool) {
        let centerIndex = UInt32(positions.count)
        let normal = SIMD3<Float>(0, facesUp ? 1 : -1, 0)
        positions.append(SIMD3<Float>(Float(center.x), Float(posY), Float(center.z)))
        normals.append(normal)
        for point in rim {
            positions.append(SIMD3<Float>(Float(center.x + point.x), Float(posY), Float(center.z + point.y)))
            normals.append(normal)
        }
        for index in 0..<rim.count {
            let current = centerIndex + 1 + UInt32(index)
            let next = centerIndex + 1 + UInt32((index + 1) % rim.count)
            indices.append(contentsOf: facesUp ? [centerIndex, next, current] : [centerIndex, current, next])
        }
    }

    mutating func appendFloorPolygon(_ points: [SIMD2<Double>], heightY: Double = 0) {
        let triangles = PolygonTriangulator.triangulate(points)
        guard !triangles.isEmpty else { return }

        let baseIndex = UInt32(positions.count)
        let normalUp = SIMD3<Float>(0, 1, 0)
        for point in points {
            positions.append(SIMD3<Float>(Float(point.x), Float(heightY), Float(point.y)))
            normals.append(normalUp)
        }

        for (idxA, idxB, idxC) in triangles {
            let vertA = baseIndex + UInt32(idxA)
            let vertB = baseIndex + UInt32(idxB)
            let vertC = baseIndex + UInt32(idxC)
            // Mapping 2D (x, y) to 3D (x, heightY, y) flips handedness, so CCW 2D triangles wind (a, c, b) to face +Y.
            indices.append(contentsOf: [vertA, vertC, vertB])
        }
    }
}

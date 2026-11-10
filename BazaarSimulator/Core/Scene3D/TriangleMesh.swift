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
    mutating func appendCylinder(
        center: SIMD3<Double>,
        radius: Double,
        height: Double,
        segments: Int = 16
    ) {
        let segCount = max(segments, 4)
        let halfH = height / 2.0
        let bottomY = center.y - halfH
        let topY = center.y + halfH

        for index in 0..<segCount {
            let angle0 = 2.0 * Double.pi * Double(index) / Double(segCount)
            let angle1 = 2.0 * Double.pi * Double(index + 1) / Double(segCount)
            let cos0 = cos(angle0)
            let sin0 = sin(angle0)
            let cos1 = cos(angle1)
            let sin1 = sin(angle1)

            let baseIndex = UInt32(positions.count)
            positions.append(SIMD3<Float>(
                Float(center.x + radius * cos0), Float(bottomY), Float(center.z + radius * sin0)
            ))
            positions.append(SIMD3<Float>(
                Float(center.x + radius * cos1), Float(bottomY), Float(center.z + radius * sin1)
            ))
            positions.append(SIMD3<Float>(
                Float(center.x + radius * cos1), Float(topY), Float(center.z + radius * sin1)
            ))
            positions.append(SIMD3<Float>(
                Float(center.x + radius * cos0), Float(topY), Float(center.z + radius * sin0)
            ))

            normals.append(SIMD3<Float>(Float(cos0), 0, Float(sin0)))
            normals.append(SIMD3<Float>(Float(cos1), 0, Float(sin1)))
            normals.append(SIMD3<Float>(Float(cos1), 0, Float(sin1)))
            normals.append(SIMD3<Float>(Float(cos0), 0, Float(sin0)))

            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex, baseIndex + 2, baseIndex + 3
            ])
        }

        appendCylinderCaps(center: center, radius: radius, topY: topY, bottomY: bottomY, segCount: segCount)
    }

    private mutating func appendCylinderCaps(
        center: SIMD3<Double>,
        radius: Double,
        topY: Double,
        bottomY: Double,
        segCount: Int
    ) {
        let topCenterIndex = UInt32(positions.count)
        positions.append(SIMD3<Float>(Float(center.x), Float(topY), Float(center.z)))
        normals.append(SIMD3<Float>(0, 1, 0))
        for index in 0..<segCount {
            let angle = 2.0 * Double.pi * Double(index) / Double(segCount)
            let posX = Float(center.x + radius * cos(angle))
            let posZ = Float(center.z + radius * sin(angle))
            positions.append(SIMD3<Float>(posX, Float(topY), posZ))
            normals.append(SIMD3<Float>(0, 1, 0))
            let currentIdx = topCenterIndex + 1 + UInt32(index)
            let nextIdx = topCenterIndex + 1 + UInt32((index + 1) % segCount)
            indices.append(contentsOf: [topCenterIndex, nextIdx, currentIdx])
        }

        let bottomCenterIndex = UInt32(positions.count)
        positions.append(SIMD3<Float>(Float(center.x), Float(bottomY), Float(center.z)))
        normals.append(SIMD3<Float>(0, -1, 0))
        for index in 0..<segCount {
            let angle = 2.0 * Double.pi * Double(index) / Double(segCount)
            let posX = Float(center.x + radius * cos(angle))
            let posZ = Float(center.z + radius * sin(angle))
            positions.append(SIMD3<Float>(posX, Float(bottomY), posZ))
            normals.append(SIMD3<Float>(0, -1, 0))
            let currentIdx = bottomCenterIndex + 1 + UInt32(index)
            let nextIdx = bottomCenterIndex + 1 + UInt32((index + 1) % segCount)
            indices.append(contentsOf: [bottomCenterIndex, currentIdx, nextIdx])
        }
    }

    mutating func appendFloorPolygon(_ points: [SIMD2<Double>], heightY: Double = 0) {
        guard points.count >= 3 else { return }
        let baseIndex = UInt32(positions.count)
        let normalUp = SIMD3<Float>(0, 1, 0)

        for point in points {
            positions.append(SIMD3<Float>(Float(point.x), Float(heightY), Float(point.y)))
            normals.append(normalUp)
        }

        var doubleSignedArea = 0.0
        let count = points.count
        for index in 0..<count {
            let currentPoint = points[index]
            let nextPoint = points[(index + 1) % count]
            doubleSignedArea += currentPoint.x * nextPoint.y - nextPoint.x * currentPoint.y
        }

        let isCounterClockwise = doubleSignedArea > 0

        for idx in 1..<(count - 1) {
            let idxA = baseIndex
            let idxB = baseIndex + UInt32(idx)
            let idxC = baseIndex + UInt32(idx + 1)
            if isCounterClockwise {
                indices.append(contentsOf: [idxA, idxC, idxB])
            } else {
                indices.append(contentsOf: [idxA, idxB, idxC])
            }
        }
    }
}

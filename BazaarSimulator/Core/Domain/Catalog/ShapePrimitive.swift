import Foundation
import simd

enum MaterialRole: String, CaseIterable, Hashable, Sendable {
    case floor
    case wall
    case panel
    case counter
    case fascia
    case tabletop
    case frame
    case fabric
    case stage
    case slab
    case pillar
    case plant
    case sign
    case glass
    case accent
}

/// A box or cylinder in an item's local frame: +x width, +y up, +z depth (plan +y).
/// Origin is at the footprint centre on the floor.
enum ShapePrimitive: Hashable, Sendable {
    case box(center: SIMD3<Double>, size: SIMD3<Double>, yaw: Double, role: MaterialRole)
    case cylinder(center: SIMD3<Double>, radius: Double, height: Double, segments: Int, role: MaterialRole)

    var role: MaterialRole {
        switch self {
        case .box(_, _, _, let role): return role
        case .cylinder(_, _, _, _, let role): return role
        }
    }

    func translated(by offset: SIMD3<Double>) -> ShapePrimitive {
        switch self {
        case let .box(center, size, yaw, role):
            return .box(center: center + offset, size: size, yaw: yaw, role: role)
        case let .cylinder(center, radius, height, segments, role):
            return .cylinder(center: center + offset, radius: radius, height: height, segments: segments, role: role)
        }
    }

    /// Rotate about +y by `angle` radians in the plan's sense (+x toward +z).
    func rotated(by angle: Double) -> ShapePrimitive {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        switch self {
        case let .box(center, size, yaw, role):
            let newCenter = SIMD3<Double>(
                center.x * cosAngle - center.z * sinAngle,
                center.y,
                center.x * sinAngle + center.z * cosAngle
            )
            return .box(center: newCenter, size: size, yaw: yaw + angle, role: role)
        case let .cylinder(center, radius, height, segments, role):
            let newCenter = SIMD3<Double>(
                center.x * cosAngle - center.z * sinAngle,
                center.y,
                center.x * sinAngle + center.z * cosAngle
            )
            return .cylinder(center: newCenter, radius: radius, height: height, segments: segments, role: role)
        }
    }

    /// Axis-aligned bounding box of this primitive in its local frame.
    var bounds: (min: SIMD3<Double>, max: SIMD3<Double>) {
        switch self {
        case let .box(center, size, yaw, _):
            let halfW = size.x / 2.0
            let halfH = size.y / 2.0
            let halfD = size.z / 2.0
            if abs(yaw) < 0.0001 {
                return (
                    min: center - SIMD3<Double>(halfW, halfH, halfD),
                    max: center + SIMD3<Double>(halfW, halfH, halfD)
                )
            }
            let cosYaw = cos(yaw)
            let sinYaw = sin(yaw)
            let corners = [
                SIMD2<Double>(-halfW, -halfD),
                SIMD2<Double>(halfW, -halfD),
                SIMD2<Double>(-halfW, halfD),
                SIMD2<Double>(halfW, halfD)
            ].map { point in
                SIMD2<Double>(
                    point.x * cosYaw - point.y * sinYaw,
                    point.x * sinYaw + point.y * cosYaw
                )
            }
            let minX = corners.map(\.x).min() ?? -halfW
            let maxX = corners.map(\.x).max() ?? halfW
            let minZ = corners.map(\.y).min() ?? -halfD
            let maxZ = corners.map(\.y).max() ?? halfD
            return (
                min: SIMD3<Double>(center.x + minX, center.y - halfH, center.z + minZ),
                max: SIMD3<Double>(center.x + maxX, center.y + halfH, center.z + maxZ)
            )
        case let .cylinder(center, radius, height, _, _):
            let halfH = height / 2.0
            return (
                min: SIMD3<Double>(center.x - radius, center.y - halfH, center.z - radius),
                max: SIMD3<Double>(center.x + radius, center.y + halfH, center.z + radius)
            )
        }
    }
}

enum Shapes {
    static func box(
        center: SIMD3<Double>,
        size: SIMD3<Double>,
        role: MaterialRole,
        yaw: Double = 0
    ) -> ShapePrimitive {
        .box(center: center, size: size, yaw: yaw, role: role)
    }

    static func legs(
        width: Double, depth: Double, height: Double,
        role: MaterialRole, thickness: Double = 0.05, inset: Double = 0.05
    ) -> [ShapePrimitive] {
        let maxInsetX = max(0, (width - thickness) / 2.0)
        let maxInsetZ = max(0, (depth - thickness) / 2.0)
        let clampedX = max(0, min(inset, maxInsetX))
        let clampedZ = max(0, min(inset, maxInsetZ))
        let centerX = max(0, width / 2.0 - clampedX - thickness / 2.0)
        let centerZ = max(0, depth / 2.0 - clampedZ - thickness / 2.0)
        let centerY = height / 2.0
        let legSize = SIMD3(thickness, height, thickness)
        return [
            .box(center: SIMD3(centerX, centerY, centerZ), size: legSize, yaw: 0, role: role),
            .box(center: SIMD3(-centerX, centerY, centerZ), size: legSize, yaw: 0, role: role),
            .box(center: SIMD3(-centerX, centerY, -centerZ), size: legSize, yaw: 0, role: role),
            .box(center: SIMD3(centerX, centerY, -centerZ), size: legSize, yaw: 0, role: role)
        ]
    }

    static func pedestal(height: Double, topRadius: Double, role: MaterialRole) -> [ShapePrimitive] {
        let baseRadius = min(topRadius * 0.75, 0.35)
        let baseHeight = min(0.04, height * 0.1)
        let columnRadius = min(0.05, topRadius * 0.2)
        let columnHeight = max(0, height - baseHeight)
        return [
            .cylinder(
                center: SIMD3(0, baseHeight / 2.0, 0),
                radius: baseRadius,
                height: baseHeight,
                segments: 16,
                role: role
            ),
            .cylinder(
                center: SIMD3(0, baseHeight + columnHeight / 2.0, 0),
                radius: columnRadius,
                height: columnHeight,
                segments: 12,
                role: role
            )
        ]
    }

    static func radial(_ parts: [ShapePrimitive], count: Int, startAngle: Double = 0) -> [ShapePrimitive] {
        guard count > 0 else { return [] }
        var result: [ShapePrimitive] = []
        result.reserveCapacity(parts.count * count)
        let step = (2.0 * .pi) / Double(count)
        for index in 0..<count {
            let angle = startAngle + Double(index) * step
            for part in parts {
                result.append(part.rotated(by: angle))
            }
        }
        return result
    }
}

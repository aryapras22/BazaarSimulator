import Foundation
import simd

struct BoundingBox: Hashable, Sendable {
    var minX: Double
    var maxX: Double
    var minY: Double
    var maxY: Double
}

enum LayoutGeometry {
    private static let epsilon = 1e-6
    private static let roundOutlineSegments = 32

    /// The footprint as a convex polygon: the four corners of a rectangle, or points around an oval.
    static func outline(of placement: Placement) -> [SIMD2<Double>] {
        guard placement.shape == .round else { return corners(of: placement) }
        let radii = placement.sizeM / 2.0
        return (0..<roundOutlineSegments).map { index in
            let angle = 2.0 * Double.pi * Double(index) / Double(roundOutlineSegments)
            return toWorld(local: SIMD2<Double>(radii.x * cos(angle), radii.y * sin(angle)), in: placement)
        }
    }

    static func corners(of placement: Placement) -> [SIMD2<Double>] {
        let halfW = placement.sizeM.x / 2.0
        let halfH = placement.sizeM.y / 2.0
        let cosAngle = cos(placement.rotationRadians)
        let sinAngle = sin(placement.rotationRadians)

        let localCorners = [
            SIMD2<Double>(-halfW, -halfH),
            SIMD2<Double>(halfW, -halfH),
            SIMD2<Double>(halfW, halfH),
            SIMD2<Double>(-halfW, halfH)
        ]

        return localCorners.map { local in
            let rotatedX = local.x * cosAngle - local.y * sinAngle
            let rotatedY = local.x * sinAngle + local.y * cosAngle
            return placement.center + SIMD2<Double>(rotatedX, rotatedY)
        }
    }

    static func bounds(of placement: Placement) -> BoundingBox {
        let pts = outline(of: placement)
        let xCoords = pts.map(\.x)
        let yCoords = pts.map(\.y)
        return BoundingBox(
            minX: xCoords.min() ?? placement.center.x,
            maxX: xCoords.max() ?? placement.center.x,
            minY: yCoords.min() ?? placement.center.y,
            maxY: yCoords.max() ?? placement.center.y
        )
    }

    static func bounds(of polygon: [SIMD2<Double>]) -> BoundingBox {
        guard let first = polygon.first else {
            return BoundingBox(minX: 0, maxX: 0, minY: 0, maxY: 0)
        }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in polygon {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return BoundingBox(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    static func toLocal(point: SIMD2<Double>, in placement: Placement) -> SIMD2<Double> {
        let delta = point - placement.center
        let cosAngle = cos(-placement.rotationRadians)
        let sinAngle = sin(-placement.rotationRadians)
        return SIMD2<Double>(
            delta.x * cosAngle - delta.y * sinAngle,
            delta.x * sinAngle + delta.y * cosAngle
        )
    }

    static func toWorld(local: SIMD2<Double>, in placement: Placement) -> SIMD2<Double> {
        let cosAngle = cos(placement.rotationRadians)
        let sinAngle = sin(placement.rotationRadians)
        return placement.center + SIMD2<Double>(
            local.x * cosAngle - local.y * sinAngle,
            local.x * sinAngle + local.y * cosAngle
        )
    }

    static func contains(_ placement: Placement, point: SIMD2<Double>, tolerance: Double = 0) -> Bool {
        let local = toLocal(point: point, in: placement)
        let halfW = placement.sizeM.x / 2.0 + tolerance
        let halfH = placement.sizeM.y / 2.0 + tolerance
        guard placement.shape == .round else {
            return abs(local.x) <= halfW + epsilon && abs(local.y) <= halfH + epsilon
        }
        guard halfW > epsilon, halfH > epsilon else { return false }
        let scaled = local / SIMD2<Double>(halfW, halfH)
        return simd_length_squared(scaled) <= 1 + epsilon
    }

    static func containsCircle(center: SIMD2<Double>, diameter: Double, point: SIMD2<Double>) -> Bool {
        let radius = diameter / 2.0
        return simd_distance_squared(center, point) <= (radius + epsilon) * (radius + epsilon)
    }

    static func intersects(_ first: Placement, _ second: Placement) -> Bool {
        let cornersA = outline(of: first)
        let cornersB = outline(of: second)
        let axes = separatingAxes(for: cornersA) + separatingAxes(for: cornersB)

        for axis in axes {
            let (minA, maxA) = project(cornersA, onto: axis)
            let (minB, maxB) = project(cornersB, onto: axis)
            // Strict overlap: touching edges do not count as intersection.
            if maxA <= minB + epsilon || maxB <= minA + epsilon {
                return false
            }
        }
        return true
    }

    static func overlapDepth(_ first: Placement, _ second: Placement) -> Double {
        let cornersA = outline(of: first)
        let cornersB = outline(of: second)
        var smallest = Double.greatestFiniteMagnitude
        for axis in separatingAxes(for: cornersA) + separatingAxes(for: cornersB) {
            let (minA, maxA) = project(cornersA, onto: axis)
            let (minB, maxB) = project(cornersB, onto: axis)
            smallest = min(smallest, min(maxA, maxB) - max(minA, minB))
        }
        return smallest
    }

    static func polygonContains(_ polygon: [SIMD2<Double>], point: SIMD2<Double>) -> Bool {
        guard polygon.count >= 3 else { return false }
        var isInside = false
        var previousIndex = polygon.count - 1
        for currentIndex in 0..<polygon.count {
            let vertexA = polygon[currentIndex]
            let vertexB = polygon[previousIndex]
            if isPoint(point, onSegmentBetween: vertexA, and: vertexB) {
                return true
            }
            let intersectsY = (vertexA.y > point.y) != (vertexB.y > point.y)
            if intersectsY {
                let slopeX = (vertexB.x - vertexA.x) * (point.y - vertexA.y) / (vertexB.y - vertexA.y) + vertexA.x
                if point.x < slopeX {
                    isInside.toggle()
                }
            }
            previousIndex = currentIndex
        }
        return isInside
    }

    static func isPlacementInsideWalkableFloor(_ placement: Placement, in layout: Layout) -> Bool {
        let pts = outline(of: placement) + [placement.center]
        return pts.allSatisfy { point in
            polygonContains(layout.hall, point: point) || polygonContains(layout.lobby, point: point)
        }
    }

    static func stripPlacement(for side: OpenSides, of placement: Placement, depthM: Double) -> Placement {
        let halfW = placement.sizeM.x / 2.0
        let halfH = placement.sizeM.y / 2.0
        let halfDepth = depthM / 2.0

        let localOffset: SIMD2<Double>
        let stripSize: SIMD2<Double>

        if side == .top {
            localOffset = SIMD2<Double>(0, -(halfH + halfDepth))
            stripSize = SIMD2<Double>(placement.sizeM.x, depthM)
        } else if side == .bottom {
            localOffset = SIMD2<Double>(0, halfH + halfDepth)
            stripSize = SIMD2<Double>(placement.sizeM.x, depthM)
        } else if side == .left {
            localOffset = SIMD2<Double>(-(halfW + halfDepth), 0)
            stripSize = SIMD2<Double>(depthM, placement.sizeM.y)
        } else {
            localOffset = SIMD2<Double>(halfW + halfDepth, 0)
            stripSize = SIMD2<Double>(depthM, placement.sizeM.y)
        }

        let worldCenter = toWorld(local: localOffset, in: placement)
        return Placement(center: worldCenter, sizeM: stripSize, rotationRadians: placement.rotationRadians)
    }

    /// A rectangle's opposite edges share an axis, so two edges are enough; any other convex outline needs every edge.
    private static func separatingAxes(for outline: [SIMD2<Double>]) -> [SIMD2<Double>] {
        guard outline.count >= 3 else { return [] }
        let edgeCount = outline.count == 4 ? 2 : outline.count
        return (0..<edgeCount).map { index in
            normalAxis(for: outline[(index + 1) % outline.count] - outline[index])
        }
    }

    private static func normalAxis(for edge: SIMD2<Double>) -> SIMD2<Double> {
        let normal = SIMD2<Double>(-edge.y, edge.x)
        let length = simd_length(normal)
        return length > epsilon ? normal / length : SIMD2<Double>(1, 0)
    }

    private static func project(_ points: [SIMD2<Double>], onto axis: SIMD2<Double>) -> (Double, Double) {
        var minVal = simd_dot(points[0], axis)
        var maxVal = minVal
        for point in points.dropFirst() {
            let projection = simd_dot(point, axis)
            minVal = min(minVal, projection)
            maxVal = max(maxVal, projection)
        }
        return (minVal, maxVal)
    }

    private static func isPoint(
        _ point: SIMD2<Double>,
        onSegmentBetween start: SIMD2<Double>,
        and end: SIMD2<Double>
    ) -> Bool {
        let cross = (point.y - start.y) * (end.x - start.x) - (point.x - start.x) * (end.y - start.y)
        guard abs(cross) <= epsilon else { return false }
        let dot = (point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)
        guard dot >= -epsilon else { return false }
        let lengthSquared = simd_distance_squared(start, end)
        return dot <= lengthSquared + epsilon
    }
}

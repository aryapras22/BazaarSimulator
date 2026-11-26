import Foundation
import simd

/// Splits a simple 2D polygon into counter-clockwise triangles using ear clipping.
nonisolated enum PolygonTriangulator {
    private static let epsilon = 1e-9

    static func triangulate(_ polygon: [SIMD2<Double>]) -> [(Int, Int, Int)] {
        guard polygon.count >= 3 else { return [] }
        let area = twiceSignedArea(polygon)
        guard abs(area) > epsilon else { return [] }

        var ring = area > 0 ? Array(polygon.indices) : Array(polygon.indices.reversed())
        ring = stripDegenerateVertices(from: ring, polygon: polygon)
        guard ring.count >= 3 else { return [] }

        var triangles: [(Int, Int, Int)] = []
        triangles.reserveCapacity(ring.count - 2)

        while ring.count > 3 {
            if let earPosition = findEar(in: ring, polygon: polygon, allowBoundaryTouch: false) {
                clipEar(at: earPosition, from: &ring, into: &triangles)
            } else if removeCollinearVertex(from: &ring, polygon: polygon) {
                continue
            } else if let earPosition = findEar(in: ring, polygon: polygon, allowBoundaryTouch: true) {
                clipEar(at: earPosition, from: &ring, into: &triangles)
            } else {
                break
            }
        }

        if ring.count == 3 {
            let ptA = polygon[ring[0]]
            let ptB = polygon[ring[1]]
            let ptC = polygon[ring[2]]
            if cross2D(ptB - ptA, ptC - ptA) > epsilon {
                triangles.append((ring[0], ring[1], ring[2]))
            }
        }
        return triangles
    }

    private static func clipEar(
        at position: Int,
        from ring: inout [Int],
        into triangles: inout [(Int, Int, Int)]
    ) {
        let count = ring.count
        let prev = ring[(position - 1 + count) % count]
        let curr = ring[position]
        let next = ring[(position + 1) % count]
        triangles.append((prev, curr, next))
        ring.remove(at: position)
    }

    private static func findEar(
        in ring: [Int],
        polygon: [SIMD2<Double>],
        allowBoundaryTouch: Bool
    ) -> Int? {
        let count = ring.count
        for position in 0..<count {
            let prev = ring[(position - 1 + count) % count]
            let curr = ring[position]
            let next = ring[(position + 1) % count]
            let ptA = polygon[prev]
            let ptB = polygon[curr]
            let ptC = polygon[next]
            guard cross2D(ptB - ptA, ptC - ptB) > epsilon else { continue }
            if !containsOtherVertex(
                in: ring,
                corners: (prev, curr, next),
                polygon: polygon,
                allowBoundaryTouch: allowBoundaryTouch
            ) {
                return position
            }
        }
        return nil
    }

    private static func containsOtherVertex(
        in ring: [Int],
        corners: (Int, Int, Int),
        polygon: [SIMD2<Double>],
        allowBoundaryTouch: Bool
    ) -> Bool {
        let ptA = polygon[corners.0]
        let ptB = polygon[corners.1]
        let ptC = polygon[corners.2]
        let margin = allowBoundaryTouch ? epsilon : -epsilon
        for index in ring where index != corners.0 && index != corners.1 && index != corners.2 {
            let point = polygon[index]
            let d1 = cross2D(ptB - ptA, point - ptA)
            let d2 = cross2D(ptC - ptB, point - ptB)
            let d3 = cross2D(ptA - ptC, point - ptC)
            if d1 >= margin && d2 >= margin && d3 >= margin {
                return true
            }
        }
        return false
    }

    private static func stripDegenerateVertices(from ring: [Int], polygon: [SIMD2<Double>]) -> [Int] {
        var result = ring
        var changed = true
        while changed && result.count >= 3 {
            changed = false
            var index = 0
            while index < result.count && result.count >= 3 {
                let count = result.count
                let prev = polygon[result[(index - 1 + count) % count]]
                let curr = polygon[result[index]]
                let next = polygon[result[(index + 1) % count]]
                if simd_distance_squared(prev, curr) <= epsilon * epsilon
                    || abs(cross2D(curr - prev, next - curr)) <= epsilon {
                    result.remove(at: index)
                    changed = true
                } else {
                    index += 1
                }
            }
        }
        return result
    }

    private static func removeCollinearVertex(from ring: inout [Int], polygon: [SIMD2<Double>]) -> Bool {
        let count = ring.count
        for index in 0..<count {
            let prev = polygon[ring[(index - 1 + count) % count]]
            let curr = polygon[ring[index]]
            let next = polygon[ring[(index + 1) % count]]
            if abs(cross2D(curr - prev, next - curr)) <= epsilon {
                ring.remove(at: index)
                return true
            }
        }
        return false
    }

    private static func twiceSignedArea(_ polygon: [SIMD2<Double>]) -> Double {
        var sum = 0.0
        for index in polygon.indices {
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            sum += current.x * next.y - next.x * current.y
        }
        return sum
    }

    private static func cross2D(_ first: SIMD2<Double>, _ second: SIMD2<Double>) -> Double {
        first.x * second.y - first.y * second.x
    }
}

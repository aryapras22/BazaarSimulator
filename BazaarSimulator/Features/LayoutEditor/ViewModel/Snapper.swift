import Foundation
import simd

enum SnapKind: String, Sendable, Equatable, Hashable, CaseIterable {
    case wallEndpoint
    case wallFace
    case boothEdge
    case boothCenter
    case alignment
    case grid
    case none
}

struct SnapGuide: Equatable, Sendable {
    var start: SIMD2<Double>
    var end: SIMD2<Double>
    var kind: SnapKind
}

struct SnapResult: Equatable, Sendable {
    var point: SIMD2<Double>
    var kind: SnapKind
    var guides: [SnapGuide]
}

enum Snapper {
    static let tolerancePt: Double = 10.0
    static let gridStepM: Double = 0.25

    static func tolerance(pointsPerMetre: Double) -> Double {
        tolerancePt / max(pointsPerMetre, 1e-4)
    }

    static func snap(
        point: SIMD2<Double>,
        layout: Layout,
        pointsPerMetre: Double,
        isFree: Bool = false,
        ignoringObjectID: UUID? = nil
    ) -> SnapResult {
        if isFree {
            return SnapResult(point: point, kind: .none, guides: [])
        }

        let toleranceM = tolerance(pointsPerMetre: pointsPerMetre)
        let wallSegments = collectWallSegments(in: layout, ignoringObjectID: ignoringObjectID)

        if let endpointSnap = snapWallEndpoints(point: point, segments: wallSegments, toleranceM: toleranceM) {
            return endpointSnap
        }
        if let faceSnap = snapWallFaces(point: point, segments: wallSegments, toleranceM: toleranceM) {
            return faceSnap
        }
        if let boothSnap = snapBooths(point: point, in: layout, toleranceM: toleranceM, ignoring: ignoringObjectID) {
            return boothSnap
        }
        if let alignSnap = snapAlignment(point: point, in: layout, toleranceM: toleranceM, ignoring: ignoringObjectID) {
            return alignSnap
        }
        if let gridSnap = snapGrid(point: point, toleranceM: toleranceM) {
            return gridSnap
        }

        return SnapResult(point: point, kind: .none, guides: [])
    }

    private struct WallSegment {
        let start: SIMD2<Double>
        let end: SIMD2<Double>
    }

    private struct AlignmentMatch {
        let coord: Double
        let refCoord: Double
        let distance: Double
    }

    private static func collectWallSegments(in layout: Layout, ignoringObjectID: UUID?) -> [WallSegment] {
        var segments: [WallSegment] = []
        for object in layout.objects where object.id != ignoringObjectID {
            guard object.kind == .wall || object.kind == .rail else { continue }
            let halfLength = object.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: object.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: object.placement)
            segments.append(WallSegment(start: start, end: end))
        }
        appendPolygonSegments(polygon: layout.hall, into: &segments)
        appendPolygonSegments(polygon: layout.lobby, into: &segments)
        return segments
    }

    private static func appendPolygonSegments(polygon: [SIMD2<Double>], into segments: inout [WallSegment]) {
        guard polygon.count >= 3 else { return }
        for index in 0..<polygon.count {
            let nextIndex = (index + 1) % polygon.count
            segments.append(WallSegment(start: polygon[index], end: polygon[nextIndex]))
        }
    }

    private static func snapWallEndpoints(
        point: SIMD2<Double>,
        segments: [WallSegment],
        toleranceM: Double
    ) -> SnapResult? {
        var bestEndpoint: SIMD2<Double>?
        var bestSegment: WallSegment?
        var bestDist = toleranceM

        for seg in segments {
            for endpoint in [seg.start, seg.end] {
                let dist = simd_distance(point, endpoint)
                if dist <= bestDist {
                    bestDist = dist
                    bestEndpoint = endpoint
                    bestSegment = seg
                }
            }
        }

        guard let bestEndpoint, let bestSegment else { return nil }
        let guide = SnapGuide(start: bestSegment.start, end: bestSegment.end, kind: .wallEndpoint)
        return SnapResult(point: bestEndpoint, kind: .wallEndpoint, guides: [guide])
    }

    private static func snapWallFaces(
        point: SIMD2<Double>,
        segments: [WallSegment],
        toleranceM: Double
    ) -> SnapResult? {
        var bestPoint: SIMD2<Double>?
        var bestSegment: WallSegment?
        var bestDist = toleranceM

        for seg in segments {
            let vector = seg.end - seg.start
            let length = simd_length(vector)
            guard length > 1e-6 else { continue }
            let tangent = vector / length
            let proj = simd_dot(point - seg.start, tangent)
            let clamped = min(max(proj, 0.0), length)
            let closest = seg.start + tangent * clamped
            let dist = simd_distance(point, closest)
            if dist <= bestDist {
                bestDist = dist
                bestPoint = closest
                bestSegment = seg
            }
        }

        guard let bestPoint, let bestSegment else { return nil }
        let guide = SnapGuide(start: bestSegment.start, end: bestSegment.end, kind: .wallFace)
        return SnapResult(point: bestPoint, kind: .wallFace, guides: [guide])
    }

    private static func snapBooths(
        point: SIMD2<Double>,
        in layout: Layout,
        toleranceM: Double,
        ignoring: UUID?
    ) -> SnapResult? {
        var bestPoint: SIMD2<Double>?
        var bestDist = toleranceM
        var bestKind: SnapKind = .boothEdge
        var bestGuide: SnapGuide?

        for object in layout.objects where object.kind == .booth && object.id != ignoring {
            let centerDist = simd_distance(point, object.placement.center)
            if centerDist <= bestDist {
                bestDist = centerDist
                bestPoint = object.placement.center
                bestKind = .boothCenter
                bestGuide = nil
            }

            let corners = LayoutGeometry.corners(of: object.placement)
            for index in 0..<corners.count {
                let nextIndex = (index + 1) % corners.count
                let segStart = corners[index]
                let segEnd = corners[nextIndex]
                let vector = segEnd - segStart
                let length = simd_length(vector)
                guard length > 1e-6 else { continue }
                let tangent = vector / length
                let proj = min(max(simd_dot(point - segStart, tangent), 0.0), length)
                let closest = segStart + tangent * proj
                let dist = simd_distance(point, closest)
                if dist <= bestDist {
                    bestDist = dist
                    bestPoint = closest
                    bestKind = .boothEdge
                    bestGuide = SnapGuide(start: segStart, end: segEnd, kind: .boothEdge)
                }
            }
        }

        guard let bestPoint else { return nil }
        let guides = bestGuide.map { [$0] } ?? []
        return SnapResult(point: bestPoint, kind: bestKind, guides: guides)
    }

    private static func snapAlignment(
        point: SIMD2<Double>,
        in layout: Layout,
        toleranceM: Double,
        ignoring: UUID?
    ) -> SnapResult? {
        var bestX: AlignmentMatch?
        var bestY: AlignmentMatch?

        for object in layout.objects where object.id != ignoring {
            let box = LayoutGeometry.bounds(of: object.placement)
            let center = object.placement.center

            for candX in [box.minX, center.x, box.maxX] {
                let dist = abs(point.x - candX)
                if dist <= toleranceM && (bestX == nil || dist < bestX!.distance) {
                    bestX = AlignmentMatch(coord: candX, refCoord: center.y, distance: dist)
                }
            }

            for candY in [box.minY, center.y, box.maxY] {
                let dist = abs(point.y - candY)
                if dist <= toleranceM && (bestY == nil || dist < bestY!.distance) {
                    bestY = AlignmentMatch(coord: candY, refCoord: center.x, distance: dist)
                }
            }
        }

        guard bestX != nil || bestY != nil else { return nil }
        return buildAlignmentResult(point: point, bestX: bestX, bestY: bestY)
    }

    private static func buildAlignmentResult(
        point: SIMD2<Double>,
        bestX: AlignmentMatch?,
        bestY: AlignmentMatch?
    ) -> SnapResult {
        let snappedPoint = SIMD2<Double>(bestX?.coord ?? point.x, bestY?.coord ?? point.y)
        var guides: [SnapGuide] = []

        if let bestX {
            var start = SIMD2<Double>(bestX.coord, bestX.refCoord)
            var end = SIMD2<Double>(bestX.coord, snappedPoint.y)
            if abs(start.y - end.y) < 1e-4 {
                start.y -= 1.0
                end.y += 1.0
            }
            guides.append(SnapGuide(start: start, end: end, kind: .alignment))
        }

        if let bestY {
            var start = SIMD2<Double>(bestY.refCoord, bestY.coord)
            var end = SIMD2<Double>(snappedPoint.x, bestY.coord)
            if abs(start.x - end.x) < 1e-4 {
                start.x -= 1.0
                end.x += 1.0
            }
            guides.append(SnapGuide(start: start, end: end, kind: .alignment))
        }

        return SnapResult(point: snappedPoint, kind: .alignment, guides: guides)
    }

    private static func snapGrid(point: SIMD2<Double>, toleranceM: Double) -> SnapResult? {
        let gridX = (point.x / gridStepM).rounded() * gridStepM
        let gridY = (point.y / gridStepM).rounded() * gridStepM
        let gridPoint = SIMD2<Double>(gridX, gridY)
        let dist = simd_distance(point, gridPoint)
        guard dist <= toleranceM else { return nil }
        return SnapResult(point: gridPoint, kind: .grid, guides: [])
    }
}

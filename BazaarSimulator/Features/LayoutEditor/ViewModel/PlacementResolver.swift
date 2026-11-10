import Foundation
import simd

struct PlacementCandidate: Equatable, Sendable {
    let placement: Placement
    let isValid: Bool
    let note: String?
    var guides: [SnapGuide] = []
}

enum PlacementResolver {
    static let gridSnapCellM: Double = 0.25

    // swiftlint:disable:next function_parameter_count
    static func resolve(
        size: SIMD2<Double>,
        at point: SIMD2<Double>,
        extraRotationDegrees: Int,
        kind: LayoutObjectKind,
        in layout: Layout,
        pointsPerMetre: Double = 10.0,
        free: Bool
    ) -> PlacementCandidate {
        let reachM = Snapper.tolerance(pointsPerMetre: pointsPerMetre)
        let placement: Placement
        var guides: [SnapGuide] = []

        if free {
            let rotation = Double(extraRotationDegrees) * .pi / 180.0
            placement = Placement(center: point, sizeM: size, rotationRadians: rotation)
        } else if kind == .booth, let snap = snapToNeighborBooth(size: size, near: point, in: layout, reach: reachM) {
            placement = snap.placement
            guides = [snap.guide]
        } else if let align = alignToNearestWall(size: size, near: point, in: layout, reach: reachM) {
            placement = align.placement
            guides = [align.guide]
        } else {
            placement = snapToGrid(size: size, at: point, extraRotationDegrees: extraRotationDegrees)
        }

        let (isValid, note) = validateCandidate(placement, in: layout)
        return PlacementCandidate(placement: placement, isValid: isValid, note: note, guides: guides)
    }

    private struct SideEvaluation {
        let distance: Double
        let placement: Placement
        let guide: SnapGuide
    }

    private struct WallSegment {
        let startPoint: SIMD2<Double>
        let endPoint: SIMD2<Double>
        let thickness: Double
    }

    private static func snapToNeighborBooth(
        size: SIMD2<Double>,
        near point: SIMD2<Double>,
        in layout: Layout,
        reach: Double
    ) -> SideEvaluation? {
        var best: SideEvaluation?
        var bestDistance = reach

        let booths = layout.objects.filter { $0.kind == .booth }
        for booth in booths {
            let candidate = evaluateBoothSides(
                booth: booth.placement,
                newSize: size,
                pointer: point,
                maxReach: bestDistance
            )
            if let candidate, candidate.distance < bestDistance {
                bestDistance = candidate.distance
                best = candidate
            }
        }
        return best
    }

    private struct BoothSide {
        let localCenter: SIMD2<Double>
        let edgePoint: SIMD2<Double>
        let segStart: SIMD2<Double>
        let segEnd: SIMD2<Double>
    }

    private static func boothSides(
        halfW: Double,
        halfD: Double,
        local: SIMD2<Double>,
        newSize: SIMD2<Double>
    ) -> [BoothSide] {
        [
            BoothSide(
                localCenter: SIMD2<Double>(-halfW - newSize.x / 2.0, 0),
                edgePoint: SIMD2<Double>(-halfW, min(max(local.y, -halfD), halfD)),
                segStart: SIMD2<Double>(-halfW, -halfD),
                segEnd: SIMD2<Double>(-halfW, halfD)
            ),
            BoothSide(
                localCenter: SIMD2<Double>(halfW + newSize.x / 2.0, 0),
                edgePoint: SIMD2<Double>(halfW, min(max(local.y, -halfD), halfD)),
                segStart: SIMD2<Double>(halfW, -halfD),
                segEnd: SIMD2<Double>(halfW, halfD)
            ),
            BoothSide(
                localCenter: SIMD2<Double>(0, -halfD - newSize.y / 2.0),
                edgePoint: SIMD2<Double>(min(max(local.x, -halfW), halfW), -halfD),
                segStart: SIMD2<Double>(-halfW, -halfD),
                segEnd: SIMD2<Double>(halfW, -halfD)
            ),
            BoothSide(
                localCenter: SIMD2<Double>(0, halfD + newSize.y / 2.0),
                edgePoint: SIMD2<Double>(min(max(local.x, -halfW), halfW), halfD),
                segStart: SIMD2<Double>(-halfW, halfD),
                segEnd: SIMD2<Double>(halfW, halfD)
            )
        ]
    }

    private static func evaluateBoothSides(
        booth: Placement,
        newSize: SIMD2<Double>,
        pointer: SIMD2<Double>,
        maxReach: Double
    ) -> SideEvaluation? {
        let delta = pointer - booth.center
        let cosAngle = cos(-booth.rotationRadians)
        let sinAngle = sin(-booth.rotationRadians)
        let local = SIMD2<Double>(
            delta.x * cosAngle - delta.y * sinAngle,
            delta.x * sinAngle + delta.y * cosAngle
        )
        let sides = boothSides(
            halfW: booth.sizeM.x / 2.0,
            halfD: booth.sizeM.y / 2.0,
            local: local,
            newSize: newSize
        )

        var best: SideEvaluation?
        var currentMin = maxReach

        for side in sides {
            let dist = simd_distance(local, side.edgePoint)
            if dist < currentMin {
                currentMin = dist
                let worldCenter = LayoutGeometry.toWorld(local: side.localCenter, in: booth)
                let guideStart = LayoutGeometry.toWorld(local: side.segStart, in: booth)
                let guideEnd = LayoutGeometry.toWorld(local: side.segEnd, in: booth)
                let guide = SnapGuide(start: guideStart, end: guideEnd, kind: .boothEdge)
                best = SideEvaluation(
                    distance: dist,
                    placement: Placement(center: worldCenter, sizeM: newSize, rotationRadians: booth.rotationRadians),
                    guide: guide
                )
            }
        }
        return best
    }

    private static func alignToNearestWall(
        size: SIMD2<Double>,
        near point: SIMD2<Double>,
        in layout: Layout,
        reach: Double
    ) -> (placement: Placement, guide: SnapGuide)? {
        var segments: [WallSegment] = []
        for wall in layout.objects where wall.kind == .wall {
            let halfLength = wall.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: wall.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: wall.placement)
            segments.append(WallSegment(startPoint: start, endPoint: end, thickness: wall.placement.sizeM.y))
        }

        collectPerimeterSegments(polygon: layout.hall, into: &segments)
        collectPerimeterSegments(polygon: layout.lobby, into: &segments)

        var bestDistance = reach
        var bestResult: (placement: Placement, guide: SnapGuide)?

        for segment in segments {
            guard let evaluated = evaluateWallSegment(segment, near: point, size: size, maxReach: bestDistance) else {
                continue
            }
            if evaluated.distance < bestDistance {
                bestDistance = evaluated.distance
                let guide = SnapGuide(start: segment.startPoint, end: segment.endPoint, kind: .wallFace)
                bestResult = (evaluated.placement, guide)
            }
        }
        return bestResult
    }

    private static func collectPerimeterSegments(polygon: [SIMD2<Double>], into segments: inout [WallSegment]) {
        guard polygon.count >= 3 else { return }
        for index in 0..<polygon.count {
            let nextIndex = (index + 1) % polygon.count
            segments.append(
                WallSegment(
                    startPoint: polygon[index],
                    endPoint: polygon[nextIndex],
                    thickness: DoorHosting.defaultThicknessM
                )
            )
        }
    }

    private static func evaluateWallSegment(
        _ segment: WallSegment,
        near point: SIMD2<Double>,
        size: SIMD2<Double>,
        maxReach: Double
    ) -> (distance: Double, placement: Placement)? {
        let segmentVector = segment.endPoint - segment.startPoint
        let segmentLength = simd_length(segmentVector)
        guard segmentLength > 1e-6 else { return nil }

        let tangent = segmentVector / segmentLength
        let vectorToPoint = point - segment.startPoint
        let projection = simd_dot(vectorToPoint, tangent)
        let clampedProjection = min(max(projection, 0), segmentLength)
        let closestPoint = segment.startPoint + tangent * clampedProjection
        let distance = simd_distance(point, closestPoint)

        guard distance <= maxReach else { return nil }

        let normalPerpendicular = SIMD2<Double>(-tangent.y, tangent.x)
        let dotProduct = simd_dot(point - closestPoint, normalPerpendicular)
        let outwardNormal = dotProduct >= 0 ? normalPerpendicular : -normalPerpendicular

        let rotation = atan2(-outwardNormal.x, outwardNormal.y)
        let offsetDistance = segment.thickness / 2.0 + size.y / 2.0
        let center = closestPoint + outwardNormal * offsetDistance

        return (
            distance: distance,
            placement: Placement(center: center, sizeM: size, rotationRadians: rotation)
        )
    }

    private static func snapToGrid(
        size: SIMD2<Double>,
        at point: SIMD2<Double>,
        extraRotationDegrees: Int
    ) -> Placement {
        let snappedCenter = SIMD2<Double>(
            (point.x / gridSnapCellM).rounded() * gridSnapCellM,
            (point.y / gridSnapCellM).rounded() * gridSnapCellM
        )
        let rotation = Double(extraRotationDegrees) * .pi / 180.0
        return Placement(center: snappedCenter, sizeM: size, rotationRadians: rotation)
    }

    private static func validateCandidate(
        _ placement: Placement,
        in layout: Layout
    ) -> (isValid: Bool, note: String?) {
        var inset = placement
        inset.sizeM = SIMD2<Double>(
            max(0.01, inset.sizeM.x - 2 * LayoutValidator.floorToleranceM),
            max(0.01, inset.sizeM.y - 2 * LayoutValidator.floorToleranceM)
        )

        let isInsideFloor = layout.hall.isEmpty && layout.lobby.isEmpty
            ? true
            : LayoutGeometry.isPlacementInsideWalkableFloor(inset, in: layout)

        if !isInsideFloor {
            return (false, "Outside floor bounds")
        }

        let blockedAreas = layout.objects.filter { $0.kind == .closedArea }
        let overlapsBlocked = blockedAreas.contains { area in
            LayoutGeometry.overlapDepth(placement, area.placement) > 0.1
        }

        if overlapsBlocked {
            return (false, "Overlaps blocked area")
        }

        let overlapped = layout.objects.first { other in
            (other.kind == .booth || other.kind == .wall)
                && LayoutGeometry.overlapDepth(placement, other.placement) > 0.1
        }
        if let overlapped {
            return (true, "Overlaps \(overlapped.label)")
        }

        return (true, nil)
    }
}

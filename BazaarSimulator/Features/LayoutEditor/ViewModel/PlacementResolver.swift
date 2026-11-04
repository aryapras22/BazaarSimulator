import Foundation
import simd

struct PlacementCandidate: Equatable, Sendable {
    let placement: Placement
    let isValid: Bool
    let note: String?
}

enum PlacementResolver {
    static let wallReachM: Double = 1.2
    static let boothSnapReachM: Double = 0.6
    static let gridSnapCellM: Double = 0.25

    // swiftlint:disable:next function_parameter_count
    static func resolve(
        size: SIMD2<Double>,
        at point: SIMD2<Double>,
        extraRotationDegrees: Int,
        kind: LayoutObjectKind,
        in layout: Layout,
        free: Bool
    ) -> PlacementCandidate {
        let placement: Placement
        if free {
            let rotation = Double(extraRotationDegrees) * .pi / 180.0
            placement = Placement(center: point, sizeM: size, rotationRadians: rotation)
        } else if kind == .booth, let snapped = snapToNeighborBooth(size: size, near: point, in: layout) {
            placement = snapped
        } else if let aligned = alignToNearestWall(size: size, near: point, in: layout) {
            placement = aligned
        } else {
            placement = snapToGrid(size: size, at: point, extraRotationDegrees: extraRotationDegrees)
        }

        let (isValid, note) = validateCandidate(placement, in: layout)
        return PlacementCandidate(placement: placement, isValid: isValid, note: note)
    }

    private static func snapToNeighborBooth(
        size: SIMD2<Double>,
        near point: SIMD2<Double>,
        in layout: Layout
    ) -> Placement? {
        var bestDistance = boothSnapReachM
        var bestPlacement: Placement?

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
                bestPlacement = candidate.placement
            }
        }
        return bestPlacement
    }

    private struct SideEvaluation {
        let distance: Double
        let placement: Placement
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
        let localPoint = SIMD2<Double>(
            delta.x * cosAngle - delta.y * sinAngle,
            delta.x * sinAngle + delta.y * cosAngle
        )

        let halfWidth = booth.sizeM.x / 2.0
        let halfDepth = booth.sizeM.y / 2.0

        let sides: [(localCenter: SIMD2<Double>, edgePoint: SIMD2<Double>)] = [
            (
                SIMD2<Double>(-halfWidth - newSize.x / 2.0, 0),
                SIMD2<Double>(-halfWidth, min(max(localPoint.y, -halfDepth), halfDepth))
            ),
            (
                SIMD2<Double>(halfWidth + newSize.x / 2.0, 0),
                SIMD2<Double>(halfWidth, min(max(localPoint.y, -halfDepth), halfDepth))
            ),
            (
                SIMD2<Double>(0, -halfDepth - newSize.y / 2.0),
                SIMD2<Double>(min(max(localPoint.x, -halfWidth), halfWidth), -halfDepth)
            ),
            (
                SIMD2<Double>(0, halfDepth + newSize.y / 2.0),
                SIMD2<Double>(min(max(localPoint.x, -halfWidth), halfWidth), halfDepth)
            )
        ]

        var best: SideEvaluation?
        var currentMin = maxReach

        for side in sides {
            let dist = simd_distance(localPoint, side.edgePoint)
            if dist < currentMin {
                currentMin = dist
                let worldCenter = LayoutGeometry.toWorld(local: side.localCenter, in: booth)
                best = SideEvaluation(
                    distance: dist,
                    placement: Placement(center: worldCenter, sizeM: newSize, rotationRadians: booth.rotationRadians)
                )
            }
        }
        return best
    }

    private struct WallSegment {
        let startPoint: SIMD2<Double>
        let endPoint: SIMD2<Double>
        let thickness: Double
    }

    private static func alignToNearestWall(
        size: SIMD2<Double>,
        near point: SIMD2<Double>,
        in layout: Layout
    ) -> Placement? {
        var segments: [WallSegment] = []
        for wall in layout.objects where wall.kind == .wall {
            let halfLength = wall.placement.sizeM.x / 2.0
            let start = LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: wall.placement)
            let end = LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: wall.placement)
            segments.append(WallSegment(startPoint: start, endPoint: end, thickness: wall.placement.sizeM.y))
        }

        collectPerimeterSegments(polygon: layout.hall, into: &segments)
        collectPerimeterSegments(polygon: layout.lobby, into: &segments)

        var bestDistance = wallReachM
        var bestPlacement: Placement?

        for segment in segments {
            guard let evaluated = evaluateWallSegment(segment, near: point, size: size, maxReach: bestDistance) else {
                continue
            }
            if evaluated.distance < bestDistance {
                bestDistance = evaluated.distance
                bestPlacement = evaluated.placement
            }
        }
        return bestPlacement
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

        // A warning, not a block: LayoutValidator already reports booth and wall overlaps after the drop.
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

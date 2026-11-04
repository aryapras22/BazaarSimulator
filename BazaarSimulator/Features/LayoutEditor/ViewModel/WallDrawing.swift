import Foundation
import simd

struct WallDrawing: Equatable, Sendable {
    var points: [SIMD2<Double>] = []
    var typedLength: String = ""

    static let snapReachM: Double = 0.5
    static let gridSnapCellM: Double = 0.25

    static func snappedPoint(
        _ pointer: SIMD2<Double>,
        from last: SIMD2<Double>?,
        in layout: Layout,
        lockAngle: Bool
    ) -> SIMD2<Double> {
        if let target = findNearestSnapTarget(to: pointer, in: layout, maxDistance: snapReachM) {
            return target
        }

        if lockAngle, let last {
            let vector = pointer - last
            let distance = simd_length(vector)
            guard distance > 1e-6 else { return last }
            let angle = atan2(vector.y, vector.x)
            let step = Double.pi / 4.0
            let snappedAngle = (angle / step).rounded() * step
            let unitDirection = SIMD2<Double>(cos(snappedAngle), sin(snappedAngle))
            let projectedDistance = simd_dot(vector, unitDirection)
            let snappedDistance = (projectedDistance / gridSnapCellM).rounded() * gridSnapCellM
            return last + unitDirection * snappedDistance
        }

        return SIMD2<Double>(
            (pointer.x / gridSnapCellM).rounded() * gridSnapCellM,
            (pointer.y / gridSnapCellM).rounded() * gridSnapCellM
        )
    }

    private static func findNearestSnapTarget(
        to pointer: SIMD2<Double>,
        in layout: Layout,
        maxDistance: Double
    ) -> SIMD2<Double>? {
        var targets: [SIMD2<Double>] = []
        for object in layout.objects where object.kind == .wall || object.kind == .rail {
            let halfLength = object.placement.sizeM.x / 2.0
            targets.append(LayoutGeometry.toWorld(local: SIMD2<Double>(-halfLength, 0), in: object.placement))
            targets.append(LayoutGeometry.toWorld(local: SIMD2<Double>(halfLength, 0), in: object.placement))
        }
        targets.append(contentsOf: layout.hall)
        targets.append(contentsOf: layout.lobby)

        var closest: SIMD2<Double>?
        var bestDistance = maxDistance
        for target in targets {
            let distance = simd_distance(pointer, target)
            if distance <= bestDistance {
                bestDistance = distance
                closest = target
            }
        }
        return closest
    }

    static func point(
        from last: SIMD2<Double>,
        toward pointer: SIMD2<Double>,
        length: Double
    ) -> SIMD2<Double> {
        let vector = pointer - last
        let distance = simd_length(vector)
        let direction = distance > 1e-6 ? vector / distance : SIMD2<Double>(1, 0)
        return last + direction * length
    }

    func objects(
        kind: LayoutObjectKind,
        thickness: Double,
        height: Double,
        catalogID: String
    ) -> [LayoutObject] {
        guard points.count >= 2 else { return [] }
        var result: [LayoutObject] = []
        for index in 0..<(points.count - 1) {
            let start = points[index]
            let end = points[index + 1]
            let vector = end - start
            let length = simd_length(vector)
            guard length > 1e-6 else { continue }
            let center = (start + end) / 2.0
            let rotation = atan2(vector.y, vector.x)
            let placement = Placement(
                center: center,
                sizeM: SIMD2<Double>(length, thickness),
                rotationRadians: rotation
            )
            let object = LayoutObject(
                id: UUID(),
                kind: kind,
                label: kind.displayName,
                placement: placement,
                catalogID: catalogID,
                heightM: height
            )
            result.append(object)
        }
        return result
    }
}

import Foundation
import simd

struct WallDrawing: Equatable, Sendable {
    var points: [SIMD2<Double>] = []
    var typedLength: String = ""

    static func snappedPoint(
        _ pointer: SIMD2<Double>,
        from last: SIMD2<Double>?,
        in layout: Layout,
        pointsPerMetre: Double = 10.0,
        lockAngle: Bool,
        isFree: Bool = false
    ) -> SIMD2<Double> {
        snap(
            pointer,
            from: last,
            in: layout,
            pointsPerMetre: pointsPerMetre,
            lockAngle: lockAngle,
            isFree: isFree
        ).point
    }

    static func snap(
        _ pointer: SIMD2<Double>,
        from last: SIMD2<Double>?,
        in layout: Layout,
        pointsPerMetre: Double = 10.0,
        lockAngle: Bool = false,
        isFree: Bool = false
    ) -> SnapResult {
        if isFree {
            return SnapResult(point: pointer, kind: .none, guides: [])
        }

        let snapResult = Snapper.snap(
            point: pointer,
            layout: layout,
            pointsPerMetre: pointsPerMetre,
            isFree: false
        )

        if snapResult.kind == .wallEndpoint || snapResult.kind == .wallFace {
            return snapResult
        }

        if lockAngle, let last {
            let vector = pointer - last
            let distance = simd_length(vector)
            guard distance > 1e-6 else {
                return SnapResult(point: last, kind: .none, guides: [])
            }
            let angle = atan2(vector.y, vector.x)
            let step = Double.pi / 4.0
            let snappedAngle = (angle / step).rounded() * step
            let unitDirection = SIMD2<Double>(cos(snappedAngle), sin(snappedAngle))
            let projectedDistance = simd_dot(vector, unitDirection)
            let snappedDistance = (projectedDistance / Snapper.gridStepM).rounded() * Snapper.gridStepM
            let snappedPoint = last + unitDirection * snappedDistance
            return SnapResult(point: snappedPoint, kind: .grid, guides: [])
        }

        return snapResult
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

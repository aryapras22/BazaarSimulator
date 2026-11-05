import Foundation
import simd

struct TableChairs: Sendable {
    static let chairSizeM = SIMD2<Double>(0.4, 0.4)
    static let edgeGapM: Double = 0.05

    static func chairPlacements(for tablePlacement: Placement, count: Int) -> [Placement] {
        guard count == 2 || count == 4 else { return [] }
        let halfWidth = tablePlacement.sizeM.x / 2.0
        let halfLength = tablePlacement.sizeM.y / 2.0
        let chairDistY = halfLength + edgeGapM + chairSizeM.y / 2.0
        let chairDistX = halfWidth + edgeGapM + chairSizeM.x / 2.0

        let localPositions: [(SIMD2<Double>, Double)]
        if count == 2 {
            if tablePlacement.sizeM.x >= tablePlacement.sizeM.y {
                localPositions = [
                    (SIMD2<Double>(0, chairDistY), Double.pi),
                    (SIMD2<Double>(0, -chairDistY), 0.0)
                ]
            } else {
                localPositions = [
                    (SIMD2<Double>(-chairDistX, 0), Double.pi / 2.0),
                    (SIMD2<Double>(chairDistX, 0), -Double.pi / 2.0)
                ]
            }
        } else {
            localPositions = [
                (SIMD2<Double>(0, chairDistY), Double.pi),
                (SIMD2<Double>(0, -chairDistY), 0.0),
                (SIMD2<Double>(-chairDistX, 0), Double.pi / 2.0),
                (SIMD2<Double>(chairDistX, 0), -Double.pi / 2.0)
            ]
        }

        let cosR = cos(tablePlacement.rotationRadians)
        let sinR = sin(tablePlacement.rotationRadians)

        return localPositions.map { localPos, localRot in
            let worldX = tablePlacement.center.x + localPos.x * cosR - localPos.y * sinR
            let worldY = tablePlacement.center.y + localPos.x * sinR + localPos.y * cosR
            let worldRot = tablePlacement.rotationRadians + localRot
            return Placement(
                center: SIMD2<Double>(worldX, worldY),
                sizeM: chairSizeM,
                rotationRadians: worldRot
            )
        }
    }
}

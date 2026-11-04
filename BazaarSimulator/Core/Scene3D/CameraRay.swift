import Foundation
import simd

enum CameraRay {
    static func floorPoint(
        viewPoint: SIMD2<Double>,
        viewSize: SIMD2<Double>,
        cameraPosition: SIMD3<Double>,
        lookAt: SIMD3<Double>,
        fieldOfViewDegrees: Double
    ) -> SIMD2<Double>? {
        guard viewSize.x > 0, viewSize.y > 0 else { return nil }
        let diff = lookAt - cameraPosition
        let dist = length(diff)
        guard dist > 1e-6 else { return nil }
        let forward = diff / dist

        let rightVector: SIMD3<Double>
        let upVector: SIMD3<Double>
        if abs(forward.y) > 0.999 {
            let fallbackUp = forward.y < 0 ? SIMD3<Double>(0, 0, -1) : SIMD3<Double>(0, 0, 1)
            rightVector = normalize(cross(forward, fallbackUp))
            upVector = cross(rightVector, forward)
        } else {
            let worldUp = SIMD3<Double>(0, 1, 0)
            rightVector = normalize(cross(forward, worldUp))
            upVector = cross(rightVector, forward)
        }

        let fovRadians = fieldOfViewDegrees * .pi / 180.0
        let halfHeightTan = tan(fovRadians / 2.0)
        let aspectRatio = viewSize.x / viewSize.y
        let halfWidthTan = halfHeightTan * aspectRatio

        let ndcX = (viewPoint.x / viewSize.x - 0.5) * 2.0
        let ndcY = (0.5 - viewPoint.y / viewSize.y) * 2.0

        let rayDir = normalize(forward + rightVector * (ndcX * halfWidthTan) + upVector * (ndcY * halfHeightTan))

        guard abs(rayDir.y) > 1e-6 else { return nil }
        let distanceToFloor = -cameraPosition.y / rayDir.y
        guard distanceToFloor > 0 else { return nil }

        let hitX = cameraPosition.x + distanceToFloor * rayDir.x
        let hitZ = cameraPosition.z + distanceToFloor * rayDir.z
        return SIMD2<Double>(hitX, hitZ)
    }
}

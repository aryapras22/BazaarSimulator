import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct CameraRayTests {
    @Test("Screen centre maps to the target floor point")
    func screenCentreHitsTarget() {
        let cameraPosition = SIMD3<Double>(20, 15, 30)
        let lookAt = SIMD3<Double>(10, 0, 15)
        let viewSize = SIMD2<Double>(800, 600)
        let centerPoint = SIMD2<Double>(400, 300)

        let hit = CameraRay.floorPoint(
            viewPoint: centerPoint,
            viewSize: viewSize,
            cameraPosition: cameraPosition,
            lookAt: lookAt,
            fieldOfViewDegrees: 46
        )

        #expect(hit != nil)
        if let hit {
            #expect(abs(hit.x - lookAt.x) < 0.001)
            #expect(abs(hit.y - lookAt.z) < 0.001)
        }
    }

    @Test("Point above the horizon has no floor hit")
    func pointAboveHorizonHasNoFloorHit() {
        let cameraPosition = SIMD3<Double>(0, 1.6, 10)
        let lookAt = SIMD3<Double>(0, 1.6, 0)
        let viewSize = SIMD2<Double>(800, 600)
        let topPoint = SIMD2<Double>(400, 100)

        let hit = CameraRay.floorPoint(
            viewPoint: topPoint,
            viewSize: viewSize,
            cameraPosition: cameraPosition,
            lookAt: lookAt,
            fieldOfViewDegrees: 46
        )

        #expect(hit == nil)
    }
}

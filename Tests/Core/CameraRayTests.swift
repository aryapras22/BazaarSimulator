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

    @Test("Plan pose picking matches the canvas orientation")
    func planPosePickingMatchesCanvas() throws {
        let rig = CameraRig(pose: CameraPose(
            target: SIMD3<Double>(10, 0, 10),
            azimuth: CameraRig.planAzimuth,
            polar: CameraRig.minPolar,
            distance: 20,
            fieldOfViewDegrees: 46
        ))
        let viewSize = SIMD2<Double>(800, 600)
        func pick(_ point: SIMD2<Double>) -> SIMD2<Double>? {
            CameraRay.floorPoint(
                viewPoint: point,
                viewSize: viewSize,
                cameraPosition: rig.cameraPosition,
                lookAt: rig.pose.target,
                fieldOfViewDegrees: rig.pose.fieldOfViewDegrees
            )
        }

        let above = try #require(pick(SIMD2<Double>(400, 100)))
        let right = try #require(pick(SIMD2<Double>(700, 300)))

        #expect(above.y < 10)
        #expect(abs(above.x - 10) < 0.01)
        #expect(right.x > 10)
        #expect(abs(right.y - 10) < 0.01)
    }

    @Test("An offset camera picks along its line of sight")
    func cameraPicksAlongSightLine() throws {
        let position = SIMD3<Double>(10, 1.6, 20)
        let forward = SIMD3<Double>(0, sin(-0.3), -cos(-0.3))
        let lookAt = position + forward

        let hit = try #require(CameraRay.floorPoint(
            viewPoint: SIMD2<Double>(400, 300),
            viewSize: SIMD2<Double>(800, 600),
            cameraPosition: position,
            lookAt: lookAt,
            fieldOfViewDegrees: 70
        ))

        #expect(abs(hit.x - 10) < 0.01)
        #expect(abs((20 - hit.y) - 1.6 / tan(0.3)) < 0.01)
    }
}

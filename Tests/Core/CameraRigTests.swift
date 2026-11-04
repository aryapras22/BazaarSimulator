import Foundation
import simd
import Testing
@testable import BazaarSimulator

@Suite
struct CameraRigTests {
    private let sampleBounds = BoundingBox(minX: 0, maxX: 40, minY: 0, maxY: 30)

    @Test("Presets set expected polar and azimuth angles")
    func presetPolarAndAzimuth() {
        let planPose = CameraRig.pose(for: .plan, framing: sampleBounds, aspect: 1.5)
        #expect(planPose.polar == CameraRig.minPolar)
        #expect(planPose.azimuth == 0.0)

        let threeDPose = CameraRig.pose(for: .threeD, framing: sampleBounds, aspect: 1.5)
        #expect(abs(threeDPose.polar - 1.02) < 1e-4)
        #expect(abs(threeDPose.azimuth - (Double.pi / 2.0 - 0.70)) < 1e-4)

        let frontPose = CameraRig.pose(for: .front, framing: sampleBounds, aspect: 1.5)
        #expect(abs(frontPose.polar - 1.35) < 1e-4)
        #expect(abs(frontPose.azimuth - Double.pi / 2.0) < 1e-4)

        let eyePose = CameraRig.pose(for: .eye, framing: sampleBounds, aspect: 1.5)
        #expect(abs(eyePose.polar - 1.35) < 1e-4)
        #expect(abs(eyePose.azimuth - Double.pi / 2.0) < 1e-4)
    }

    @Test("Tween ends exactly on the target pose")
    func tweenEndsOnTarget() {
        let startPose = CameraRig.pose(for: .plan, framing: sampleBounds, aspect: 1.5)
        let targetPose = CameraRig.pose(for: .threeD, framing: sampleBounds, aspect: 1.5)

        var rig = CameraRig(pose: startPose)
        rig.transition(to: targetPose, animated: true)

        let midwayAnimating = rig.advance(by: 0.25)
        #expect(midwayAnimating)
        #expect(rig.pose != targetPose)

        let finalAnimating = rig.advance(by: 0.35)
        #expect(!finalAnimating)
        #expect(rig.pose == targetPose)
    }

    @Test("Short-way azimuth wrap chooses shortest angular delta")
    func shortWayAzimuthWrap() {
        var startPose = CameraRig.pose(for: .plan, framing: sampleBounds, aspect: 1.5)
        startPose.azimuth = 0.1
        var targetPose = startPose
        targetPose.azimuth = Double.pi * 2.0 - 0.1

        var rig = CameraRig(pose: startPose)
        rig.transition(to: targetPose, animated: true)

        _ = rig.advance(by: CameraRig.tweenDuration * 0.5)
        // Midpoint should pass through 0 / 2pi boundary, not through pi (~3.14)
        #expect(abs(rig.pose.azimuth) < 0.2 || abs(rig.pose.azimuth - Double.pi * 2.0) < 0.2)
    }

    @Test("Zoom keeps floor point under pointer")
    func zoomKeepsPointUnderPointer() {
        let initialPose = CameraRig.pose(for: .threeD, framing: sampleBounds, aspect: 1.5)
        var rig = CameraRig(pose: initialPose)
        let floorPoint = SIMD2<Double>(25.0, 15.0)

        rig.zoom(delta: -100.0, toward: floorPoint)
        #expect(rig.pose.distance < initialPose.distance)

        // Target should shift towards floorPoint
        let initialDistToPoint = length(SIMD2<Double>(initialPose.target.x, initialPose.target.z) - floorPoint)
        let newDistToPoint = length(SIMD2<Double>(rig.pose.target.x, rig.pose.target.z) - floorPoint)
        #expect(newDistToPoint < initialDistToPoint)
    }

    @Test("Eye walk stays clamped to layout bounds")
    func eyeWalkClampedToBounds() {
        let initialPose = CameraRig.pose(for: .eye, framing: sampleBounds, aspect: 1.5)
        var rig = CameraRig(pose: initialPose, eye: EyePose(position: SIMD3<Double>(10, 1.6, 10), yaw: 0, pitch: 0))

        // Yaw 0 points forward along -z. Walking forward 100m will hit minY = 0
        rig.eyeWalk(forward: 100.0, right: 0.0, in: sampleBounds)
        #expect(rig.eye?.position.z == sampleBounds.minY)
        #expect(rig.eye?.position.y == 1.6)

        // Walk backwards 200m
        rig.eyeWalk(forward: -200.0, right: 0.0, in: sampleBounds)
        #expect(rig.eye?.position.z == sampleBounds.maxY)
    }
}

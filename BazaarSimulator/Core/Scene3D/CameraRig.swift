import Foundation
import simd

enum ViewPreset: String, CaseIterable, Hashable, Sendable {
    case plan, threeD, front, eye

    var title: String {
        switch self {
        case .plan: return "Plan"
        case .threeD: return "3D"
        case .front: return "Front"
        case .eye: return "Eye"
        }
    }
}

struct CameraPose: Equatable, Sendable {
    var target: SIMD3<Double>
    var azimuth: Double
    var polar: Double
    var distance: Double
    var fieldOfViewDegrees: Double
}

struct EyePose: Equatable, Sendable {
    var position: SIMD3<Double>
    var yaw: Double
    var pitch: Double
}

struct CameraRig: Equatable, Sendable {
    static let tweenDuration: Double = 0.55
    static let minDistance: Double = 2.0
    static let maxDistance: Double = 400.0
    static let minPolar: Double = 0.0001
    static let maxPolar: Double = Double.pi / 2.0 - 0.02
    /// Puts world -z at the top of the screen, the same way the 2D canvas puts world -y at the top.
    static let planAzimuth = Double.pi / 2.0
    static let eyeFieldOfViewDegrees: Double = 70

    private(set) var pose: CameraPose
    private(set) var eye: EyePose?
    private var fromPose: CameraPose?
    private var toPose: CameraPose?
    private var progress: Double = 1.0

    init(pose: CameraPose, eye: EyePose? = nil) {
        self.pose = pose
        self.eye = eye
    }

    var cameraPosition: SIMD3<Double> {
        if let eye {
            return eye.position
        }
        let sphericalOffset = SIMD3<Double>(
            cos(pose.azimuth) * sin(pose.polar),
            cos(pose.polar),
            sin(pose.azimuth) * sin(pose.polar)
        ) * pose.distance
        return pose.target + sphericalOffset
    }

    var lookAtPoint: SIMD3<Double> {
        guard let eye else { return pose.target }
        let forward = SIMD3<Double>(
            -sin(eye.yaw) * cos(eye.pitch),
            sin(eye.pitch),
            -cos(eye.yaw) * cos(eye.pitch)
        )
        return eye.position + forward
    }

    var activeFieldOfViewDegrees: Double {
        eye == nil ? pose.fieldOfViewDegrees : Self.eyeFieldOfViewDegrees
    }

    static func pose(for preset: ViewPreset, framing bounds: BoundingBox, aspect: Double) -> CameraPose {
        let centerX = (bounds.minX + bounds.maxX) / 2.0
        let centerZ = (bounds.minY + bounds.maxY) / 2.0
        let target = SIMD3<Double>(centerX, 0, centerZ)

        let width = max(bounds.maxX - bounds.minX, 1.0)
        let depth = max(bounds.maxY - bounds.minY, 1.0)
        let safeAspect = max(aspect, 0.1)
        let span = max(depth, width / safeAspect) * 1.25 + 2.0

        let fovDegrees = 46.0
        let fovRadians = fovDegrees * .pi / 180.0
        let rawDistance = (span / 2.0) / tan(fovRadians / 2.0)
        let distance = min(max(rawDistance, minDistance), maxDistance)

        let azimuth: Double
        let polar: Double
        switch preset {
        case .plan:
            azimuth = planAzimuth
            polar = minPolar
        case .threeD:
            azimuth = Double.pi / 2.0 - 0.70
            polar = 1.02
        case .front, .eye:
            azimuth = Double.pi / 2.0
            polar = 1.35
        }

        return CameraPose(
            target: target,
            azimuth: azimuth,
            polar: polar,
            distance: distance,
            fieldOfViewDegrees: fovDegrees
        )
    }

    mutating func orbit(deltaX: Double, deltaY: Double) {
        pose.azimuth -= deltaX * 0.006
        pose.polar = min(max(pose.polar - deltaY * 0.006, Self.minPolar), Self.maxPolar)
    }

    mutating func pan(deltaX: Double, deltaY: Double, viewHeight: Double) {
        let perPixel = worldPerPixel(viewHeight: viewHeight)
        let rightVector = SIMD3<Double>(sin(pose.azimuth), 0, -cos(pose.azimuth))
        let forwardVector = SIMD3<Double>(-cos(pose.azimuth), 0, -sin(pose.azimuth))
        pose.target += rightVector * (-deltaX * perPixel) + forwardVector * (deltaY * perPixel)
    }

    mutating func zoom(delta: Double, toward floorPoint: SIMD2<Double>?) {
        let factor = exp(delta * 0.0014)
        let newDistance = min(max(pose.distance * factor, Self.minDistance), Self.maxDistance)

        if let floorPoint, abs(newDistance - pose.distance) > 1e-6 {
            let scaleRatio = 1.0 - (newDistance / pose.distance)
            pose.target.x += (floorPoint.x - pose.target.x) * scaleRatio
            pose.target.z += (floorPoint.y - pose.target.z) * scaleRatio
        }
        pose.distance = newDistance
    }

    mutating func transition(to target: CameraPose, animated: Bool) {
        if !animated {
            pose = target
            fromPose = nil
            toPose = nil
            progress = 1.0
        } else {
            fromPose = pose
            toPose = target
            progress = 0.0
        }
    }

    mutating func advance(by seconds: Double) -> Bool {
        guard progress < 1.0, let startPose = fromPose, let targetPose = toPose else {
            return false
        }
        progress = min(1.0, progress + seconds / Self.tweenDuration)
        let eased = ease(progress)

        var deltaAzimuth = targetPose.azimuth - startPose.azimuth
        while deltaAzimuth > Double.pi { deltaAzimuth -= 2.0 * Double.pi }
        while deltaAzimuth <= -Double.pi { deltaAzimuth += 2.0 * Double.pi }

        pose = CameraPose(
            target: simd_mix(startPose.target, targetPose.target, SIMD3<Double>(repeating: eased)),
            azimuth: startPose.azimuth + deltaAzimuth * eased,
            polar: startPose.polar + (targetPose.polar - startPose.polar) * eased,
            distance: startPose.distance + (targetPose.distance - startPose.distance) * eased,
            fieldOfViewDegrees: startPose.fieldOfViewDegrees +
                (targetPose.fieldOfViewDegrees - startPose.fieldOfViewDegrees) * eased
        )

        if progress >= 1.0 {
            pose = targetPose
            fromPose = nil
            toPose = nil
            return false
        }
        return true
    }

    func worldPerPixel(viewHeight: Double) -> Double {
        guard viewHeight > 0 else { return 0.01 }
        let fovRadians = pose.fieldOfViewDegrees * .pi / 180.0
        return (2.0 * pose.distance * tan(fovRadians / 2.0)) / viewHeight
    }

    private func ease(_ timeFraction: Double) -> Double {
        if timeFraction < 0.5 {
            return 4.0 * timeFraction * timeFraction * timeFraction
        } else {
            return 1.0 - pow(-2.0 * timeFraction + 2.0, 3.0) / 2.0
        }
    }

    mutating func setEye(_ newEye: EyePose?) {
        eye = newEye
    }

    mutating func eyeLook(deltaX: Double, deltaY: Double) {
        guard var currentEye = eye else { return }
        currentEye.yaw += deltaX * 0.004
        currentEye.pitch = min(max(currentEye.pitch - deltaY * 0.004, -Double.pi / 3.0), Double.pi / 3.0)
        eye = currentEye
    }

    mutating func eyeWalk(forward: Double, right: Double, in bounds: BoundingBox) {
        guard var currentEye = eye else { return }
        let forwardVector = SIMD2<Double>(-sin(currentEye.yaw), -cos(currentEye.yaw))
        let rightVector = SIMD2<Double>(cos(currentEye.yaw), -sin(currentEye.yaw))

        var newX = currentEye.position.x + forwardVector.x * forward + rightVector.x * right
        var newZ = currentEye.position.z + forwardVector.y * forward + rightVector.y * right

        newX = min(max(newX, bounds.minX), bounds.maxX)
        newZ = min(max(newZ, bounds.minY), bounds.maxY)

        currentEye.position = SIMD3<Double>(newX, 1.6, newZ)
        eye = currentEye
    }
}

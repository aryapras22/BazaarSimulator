import Foundation
import simd

/// A camera that circles a point: drag to orbit, scroll to zoom, shift-drag to move.
struct OrbitCamera: Equatable {
    /// Narrow, so the venue reads like an axonometric drawing: far things barely shrink and uprights stay upright.
    static let fieldOfView: Float = .pi / 7
    static let minimumPitch: Float = 0.12
    static let maximumPitch: Float = 1.5
    static let nearPlane: Float = 0.5
    static let farPlane: Float = 1500

    var target: SIMD3<Float>
    /// Turn about the vertical axis. 0 looks from the south edge of the plan toward the north.
    var yaw: Float
    /// Angle above the floor, in radians.
    var pitch: Float
    var distance: Float

    /// Starts back and above the plan, looking at the middle of it, so the whole plan fits.
    static func framing(plan: PlanFrame) -> OrbitCamera {
        let span = Float(max(plan.size.x, plan.size.y))
        return OrbitCamera(
            target: SIMD3(Float(plan.origin.x + plan.size.x / 2), 0, Float(plan.origin.y + plan.size.y / 2)),
            yaw: 0,
            pitch: atan2(0.85, 0.5),
            distance: span * 0.57 / tan(fieldOfView / 2)
        )
    }

    var position: SIMD3<Float> {
        target + distance * SIMD3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
    }

    // MARK: Matrices

    var viewMatrix: float4x4 {
        let eye = position
        let forward = simd_normalize(target - eye)
        let side = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
        let up = simd_cross(side, forward)
        return float4x4(columns: (
            SIMD4(side.x, up.x, -forward.x, 0),
            SIMD4(side.y, up.y, -forward.y, 0),
            SIMD4(side.z, up.z, -forward.z, 0),
            SIMD4(-simd_dot(side, eye), -simd_dot(up, eye), simd_dot(forward, eye), 1)
        ))
    }

    func projectionMatrix(aspect: Float) -> float4x4 {
        let ys = 1 / tan(Self.fieldOfView / 2)
        let xs = ys / max(aspect, 0.01)
        let zs = Self.farPlane / (Self.nearPlane - Self.farPlane)
        return float4x4(columns: (
            SIMD4(xs, 0, 0, 0),
            SIMD4(0, ys, 0, 0),
            SIMD4(0, 0, zs, -1),
            SIMD4(0, 0, zs * Self.nearPlane, 0)
        ))
    }

    func viewProjection(aspect: Float) -> float4x4 {
        projectionMatrix(aspect: aspect) * viewMatrix
    }

    /// Which way is right and up on screen, for things that always face the camera.
    var screenAxes: (right: SIMD3<Float>, up: SIMD3<Float>) {
        let forward = simd_normalize(target - position)
        let side = simd_normalize(simd_cross(forward, SIMD3(0, 1, 0)))
        return (side, simd_cross(side, forward))
    }

    /// Where a point in the venue lands on screen, in pixels from the top left. Nil if it is behind the camera.
    func project(_ point: SIMD3<Float>, viewport: SIMD2<Float>) -> SIMD2<Float>? {
        let clip = viewProjection(aspect: viewport.x / viewport.y) * SIMD4(point, 1)
        guard clip.w > 0 else { return nil }
        let ndc = SIMD2(clip.x, clip.y) / clip.w
        return SIMD2((ndc.x * 0.5 + 0.5) * viewport.x, (0.5 - ndc.y * 0.5) * viewport.y)
    }

    // MARK: Moving

    /// Drag by `dx` and `dy` points: left and right turn around, up and down tilt.
    mutating func orbit(dx: Float, dy: Float) {
        yaw -= dx * 0.007
        pitch = min(max(pitch + dy * 0.006, Self.minimumPitch), 1.38)
    }

    /// Positive moves in, negative moves out.
    mutating func zoom(_ amount: Float) {
        distance = min(max(distance * exp(-amount * 0.01), 15), 1200)
    }

    /// Slide the view across the floor by `dx` and `dy` points.
    mutating func pan(dx: Float, dy: Float) {
        let axes = screenAxes
        let scale = distance * 0.0032 * tan(Self.fieldOfView / 2)
        let forward = simd_normalize(SIMD3(-sin(yaw), 0, -cos(yaw)))
        let pitchCompensation = 1.0 / max(sin(pitch), 0.35)
        target += (-axes.right * dx + forward * (dy * pitchCompensation)) * scale
    }
}

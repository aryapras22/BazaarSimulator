import Foundation
import simd

struct BoundingBox3D: Hashable, Sendable {
    var center: SIMD3<Double>
    var size: SIMD3<Double>
    var yaw: Double
}

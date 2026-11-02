import Foundation
import simd

struct Placement: Codable, Hashable, Sendable {
    var center: SIMD2<Double>
    var sizeM: SIMD2<Double>
    var rotationRadians: Double

    init(
        center: SIMD2<Double>,
        sizeM: SIMD2<Double>,
        rotationRadians: Double = 0
    ) {
        self.center = center
        self.sizeM = sizeM
        self.rotationRadians = rotationRadians
    }

    var rotationDegrees: Int {
        get {
            let degrees = Int((rotationRadians * 180.0 / .pi).rounded())
            return ((degrees % 360) + 360) % 360
        }
        set {
            let normalized = ((newValue % 360) + 360) % 360
            rotationRadians = Double(normalized) * .pi / 180.0
        }
    }

    func snapped(toGrid cellM: Double) -> Placement {
        guard cellM > 0 else { return self }
        var copy = self
        copy.center = SIMD2<Double>(
            (center.x / cellM).rounded() * cellM,
            (center.y / cellM).rounded() * cellM
        )
        return copy
    }

    func rotatedQuarterTurns(_ turns: Int = 1) -> Placement {
        var copy = self
        copy.rotationDegrees = (rotationDegrees + turns * 90) % 360
        return copy
    }
}

import Foundation
import simd

/// A round footprint is the oval that fills the placement's box, so equal sides give a circle.
enum FootprintShape: String, Codable, CaseIterable, Hashable, Sendable {
    case rect
    case round

    var displayName: String {
        switch self {
        case .rect: return "Rectangle"
        case .round: return "Round"
        }
    }
}

struct Placement: Codable, Hashable, Sendable {
    var center: SIMD2<Double>
    var sizeM: SIMD2<Double>
    var rotationRadians: Double
    var shape: FootprintShape

    init(
        center: SIMD2<Double>,
        sizeM: SIMD2<Double>,
        rotationRadians: Double = 0,
        shape: FootprintShape = .rect
    ) {
        self.center = center
        self.sizeM = sizeM
        self.rotationRadians = rotationRadians
        self.shape = shape
    }

    /// Layouts saved before shapes existed have no value for it, so they read as rectangles.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        center = try container.decode(SIMD2<Double>.self, forKey: .center)
        sizeM = try container.decode(SIMD2<Double>.self, forKey: .sizeM)
        rotationRadians = try container.decode(Double.self, forKey: .rotationRadians)
        shape = try container.decodeIfPresent(FootprintShape.self, forKey: .shape) ?? .rect
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

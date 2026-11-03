import Observation
import simd

@Observable
@MainActor
final class CanvasPointer {
    var world: SIMD2<Double>?
    var hitDescription: String?
}

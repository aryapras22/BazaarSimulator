import Observation
import simd

@Observable
@MainActor
final class CanvasPointer {
    var world: SIMD2<Double>?
    var hitDescription: String?
    var placementCandidate: PlacementCandidate?
    var placingSource: LibraryRowDisplay.Source?
    var wallCurrentPointer: SIMD2<Double>?
}

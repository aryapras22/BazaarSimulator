import Foundation
import simd

struct LayoutZone: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var label: String
    var minX: Double
    var maxX: Double
    var labelPosition: SIMD2<Double>

    init(
        id: UUID = UUID(),
        label: String,
        minX: Double,
        maxX: Double,
        labelPosition: SIMD2<Double>
    ) {
        self.id = id
        self.label = label
        self.minX = minX
        self.maxX = maxX
        self.labelPosition = labelPosition
    }
}

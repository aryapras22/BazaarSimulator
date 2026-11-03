import Foundation
import simd

enum LayoutMarkerKind: String, Codable, Hashable, Sendable {
    case spawn
    case exit
}

struct LayoutMarker: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var kind: LayoutMarkerKind
    var label: String
    var position: SIMD2<Double>

    init(
        id: UUID = UUID(),
        kind: LayoutMarkerKind,
        label: String,
        position: SIMD2<Double>
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.position = position
    }
}

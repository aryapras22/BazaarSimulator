import Foundation
import simd

struct LayoutSource: Codable, Hashable, Sendable {
    var name: String
    var sheet: String
    var note: String

    init(name: String = "", sheet: String = "", note: String = "") {
        self.name = name
        self.sheet = sheet
        self.note = note
    }
}

struct Layout: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var sizeM: SIMD2<Double>
    var hall: [SIMD2<Double>]
    var lobby: [SIMD2<Double>]
    var objects: [LayoutObject]
    var markers: [LayoutMarker]
    var zones: [LayoutZone]
    var source: LayoutSource

    init(
        id: UUID = UUID(),
        name: String,
        sizeM: SIMD2<Double>,
        hall: [SIMD2<Double>] = [],
        lobby: [SIMD2<Double>] = [],
        objects: [LayoutObject] = [],
        markers: [LayoutMarker] = [],
        zones: [LayoutZone] = [],
        source: LayoutSource = LayoutSource()
    ) {
        self.id = id
        self.name = name
        self.sizeM = sizeM
        self.hall = hall
        self.lobby = lobby
        self.objects = objects
        self.markers = markers
        self.zones = zones
        self.source = source
    }
}

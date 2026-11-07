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
    var furniture: [LayoutFurniture]
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
        furniture: [LayoutFurniture] = [],
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
        self.furniture = furniture
        self.source = source
    }
}

extension Layout {
    /// Layouts saved before furniture existed have none.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sizeM = try container.decode(SIMD2<Double>.self, forKey: .sizeM)
        hall = try container.decode([SIMD2<Double>].self, forKey: .hall)
        lobby = try container.decode([SIMD2<Double>].self, forKey: .lobby)
        objects = try container.decode([LayoutObject].self, forKey: .objects)
        markers = try container.decode([LayoutMarker].self, forKey: .markers)
        zones = try container.decode([LayoutZone].self, forKey: .zones)
        furniture = try container.decodeIfPresent([LayoutFurniture].self, forKey: .furniture) ?? []
        source = try container.decode(LayoutSource.self, forKey: .source)
    }
}

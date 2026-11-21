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

extension Layout {
    /// Fills `boothType` from `legend` on booths that have a `categoryID` but no saved `boothType`.
    func resolvingBoothTypes(from legend: Legend) -> Layout {
        let typesByID = Dictionary(
            uniqueKeysWithValues: legend.entries.compactMap { entry in
                entry.type.map { (entry.id, $0) }
            }
        )
        guard !typesByID.isEmpty else { return self }
        var updated = self
        for index in updated.objects.indices {
            guard updated.objects[index].kind == .booth,
                  updated.objects[index].boothType == nil,
                  let categoryID = updated.objects[index].categoryID,
                  let type = typesByID[categoryID] else {
                continue
            }
            updated.objects[index].boothType = type
        }
        return updated
    }
}

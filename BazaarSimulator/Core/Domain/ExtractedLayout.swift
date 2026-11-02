import Foundation

struct LayoutDimensions: Sendable, Hashable, Codable {
    let width: Double
    let height: Double
}

struct ExtractedLayout: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    var name: String
    var sizeInMetres: LayoutDimensions
    var booths: Int
    var doors: Int

    init(
        id: UUID = UUID(),
        name: String,
        sizeInMetres: LayoutDimensions = LayoutDimensions(width: 0, height: 0),
        booths: Int = 0,
        doors: Int = 0
    ) {
        self.id = id
        self.name = name
        self.sizeInMetres = sizeInMetres
        self.booths = booths
        self.doors = doors
    }
}

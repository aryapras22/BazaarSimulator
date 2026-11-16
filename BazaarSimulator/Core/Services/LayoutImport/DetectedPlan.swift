import Foundation

/// What a floor plan reader found, in pixels of the page image.
/// Readers fill it, `ExtractedLayoutMapper` turns it into metres.
struct DetectedPlan: Sendable, Equatable, Codable {
    var items: [DetectedItem]
    /// The scale read from sizes printed on the plan, when it prints any.
    var printedPixelsPerMetre: Double?
}

struct DetectedItem: Sendable, Equatable, Codable {
    /// "Booth B" style names for booths, a legend label for other legend classes,
    /// otherwise wall, pillar, door, opening or object.
    var cls: String
    /// x, y, width, height.
    var box: [Double]
    var id: String?
    /// A slanted or straight wall as x0, y0, x1, y1.
    var segment: [Double]?
    /// Stroke thickness of a wall.
    var widthPx: Double?
    var kind: String?
    /// Legend colour of the class, 0 to 255. Booth classes are named after an ID prefix,
    /// so this ties them to a legend entry.
    var legendRgb: [Int] = []
    var chairs: Int?
    var symbolClass: String?

    /// The extractor reads an ID only on a booth tile, so an ID marks a booth whatever its legend class is called.
    /// Plans that colour booths by country or zone have no class with "booth" in its name.
    var isBooth: Bool {
        id != nil || cls.lowercased().contains("booth")
    }
}

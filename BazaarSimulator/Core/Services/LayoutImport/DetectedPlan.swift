import Foundation

/// What a floor plan reader found, in pixels of the page image.
/// Readers fill it, `ExtractedLayoutMapper` turns it into metres.
struct DetectedPlan: Sendable, Equatable {
    var items: [DetectedItem]
}

struct DetectedItem: Sendable, Equatable {
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
}

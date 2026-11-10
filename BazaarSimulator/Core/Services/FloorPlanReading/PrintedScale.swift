import Foundation

/// A size printed on a plan, in metres, longest side first.
struct PrintedSize: Equatable, Sendable {
    let long: Double
    let short: Double
}

enum PrintedScale {
    /// Two sizes whose scales differ by more than this are not the same drawing of the same thing.
    private static let agreement = 0.2

    /// The first "6 x 12 m" or "3m x 3m" in the text.
    static func size(in text: String) -> PrintedSize? {
        let pattern = #/(\d+(?:[.,]\d+)?)\s*m?\s*[x×]\s*(\d+(?:[.,]\d+)?)\s*m\b/#.ignoresCase()
        guard let match = text.firstMatch(of: pattern),
              let first = number(match.1), let second = number(match.2)
        else { return nil }
        return PrintedSize(long: max(first, second), short: min(first, second))
    }

    private static func number(_ text: Substring) -> Double? {
        Double(text.replacing(",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The median scale over boxes whose two sides give the same scale. Boxes are x, y, width, height in pixels.
    static func pixelsPerMetre(from boxes: [(box: [Double], printed: PrintedSize)]) -> Double? {
        let scales = boxes.compactMap { entry -> Double? in
            let long = max(entry.box[2], entry.box[3])
            let short = min(entry.box[2], entry.box[3])
            let byLong = long / entry.printed.long
            let byShort = short / entry.printed.short
            guard abs(byLong - byShort) / max(byLong, byShort) <= agreement else { return nil }
            return (byLong + byShort) / 2
        }.sorted()
        return scales.isEmpty ? nil : scales[scales.count / 2]
    }
}

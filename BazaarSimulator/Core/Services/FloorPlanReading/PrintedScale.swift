import Foundation

/// A size printed on a plan, in metres, longest side first.
struct PrintedSize: Equatable, Sendable {
    let long: Double
    let short: Double
}

enum PrintedScale {
    /// Two sizes whose scales differ by more than this are not the same drawing of the same thing.
    private static let agreement = 0.2

    /// A length printed one booth away proves nothing, so a booth side counts once this many booths print it.
    private static let minimumRepeats = 3

    /// The first "6 x 12 m", "3m x 3m" or "3x8.25" in the text. Some plans leave the unit out.
    static func size(in text: String) -> PrintedSize? {
        let pattern = #/(\d+(?:[.,]\d+)?)\s*m?\s*[x×]\s*(\d+(?:[.,]\d+)?)(?:\s*m\b)?/#.ignoresCase()
        guard let match = text.firstMatch(of: pattern),
              let first = number(match.1), let second = number(match.2)
        else { return nil }
        return PrintedSize(long: max(first, second), short: min(first, second))
    }

    /// A label that is one length and nothing else, such as "3 m" beside a booth.
    static func length(in text: String) -> Double? {
        text.wholeMatch(of: #/\s*(\d+(?:[.,]\d+)?)\s*m\s*/#.ignoresCase()).flatMap { number($0.1) }
    }

    /// The length printed most often, the shorter one on a tie.
    static func mostPrinted(_ lengths: [Double]) -> Double? {
        let counts = Dictionary(grouping: lengths) { $0 }.mapValues(\.count)
        let best = counts.max { ($0.value, -$0.key) < ($1.value, -$1.key) }
        return best.flatMap { $0.value >= minimumRepeats ? $0.key : nil }
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

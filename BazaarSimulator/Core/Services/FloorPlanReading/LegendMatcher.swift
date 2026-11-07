import CoreGraphics
import Foundation

/// A project can hold several legends, one per sheet. A plan is read with the legend whose colours it uses.
enum LegendMatcher {
    private static let sampleWidth = 600
    private static let colourTolerance = 20.0
    private static let minimumPixels = 12
    /// Greys, white and black also fill text and outlines, so they say nothing about which legend a plan uses.
    private static let minimumChroma = 0.12

    /// The index of the legend whose colours cover the most of the page, or nil when none of them appear.
    /// Pixels are counted, not colours, because anti-aliased text edges put a few pixels of many colours on any page.
    static func bestMatchIndex(for page: CGImage, among legends: [Legend]) -> Int? {
        guard legends.count > 1 else { return legends.isEmpty ? nil : 0 }
        guard let pixels = samplePixels(of: page) else { return nil }
        let scores = legends.map { colourScore(of: $0, in: pixels) }
        guard let best = scores.max(), best > 0 else { return nil }
        return scores.firstIndex(of: best)
    }

    private static func colourScore(of legend: Legend, in pixels: [UInt8]) -> Int {
        let colours = legend.entries.map(\.color).filter(isChromatic)
        var counts = [Int](repeating: 0, count: colours.count)
        let limit = colourTolerance * colourTolerance
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[offset]), green = Double(pixels[offset + 1]), blue = Double(pixels[offset + 2])
            for (index, colour) in colours.enumerated() {
                let redGap = red - colour.red * 255
                let greenGap = green - colour.green * 255
                let blueGap = blue - colour.blue * 255
                if redGap * redGap + greenGap * greenGap + blueGap * blueGap <= limit { counts[index] += 1 }
            }
        }
        return counts.filter { $0 >= minimumPixels }.reduce(0, +)
    }

    private static func isChromatic(_ colour: LegendColor) -> Bool {
        max(colour.red, colour.green, colour.blue) - min(colour.red, colour.green, colour.blue) >= minimumChroma
    }

    private static func samplePixels(of page: CGImage) -> [UInt8]? {
        let width = sampleWidth
        let height = max(1, page.height * width / max(page.width, 1))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(page, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : nil
    }
}

import CoreGraphics
import Testing
@testable import BazaarSimulator

@Suite
struct LegendMatcherTests {
    private let purple = LegendColor(red: 0.7, green: 0.6, blue: 0.95)
    private let orange = LegendColor(red: 0.96, green: 0.53, blue: 0.1)
    private let grey = LegendColor(red: 0.5, green: 0.5, blue: 0.5)

    private func page(painting colour: LegendColor) -> CGImage {
        let context = CGContext(
            data: nil, width: 600, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 600, height: 600))
        context.setFillColor(CGColor(srgbRed: colour.red, green: colour.green, blue: colour.blue, alpha: 1))
        context.fill(CGRect(x: 100, y: 100, width: 80, height: 80))
        return context.makeImage()!
    }

    @Test("The legend whose colour is on the page is chosen, even when it is listed second")
    func picksLegendByColour() {
        let first = Legend(entries: [LegendEntry(name: "Booth A", color: purple)])
        let second = Legend(entries: [LegendEntry(name: "Booth A", color: orange)])

        #expect(LegendMatcher.bestMatchIndex(for: page(painting: orange), among: [first, second]) == 1)
        #expect(LegendMatcher.bestMatchIndex(for: page(painting: purple), among: [first, second]) == 0)
    }

    @Test("A few stray pixels of another legend's colour do not outweigh the legend that fills the page")
    func coverageBeatsStrayPixels() {
        let first = Legend(entries: [LegendEntry(name: "Booth A", color: purple)])
        let second = Legend(entries: [LegendEntry(name: "Booth A", color: orange)])
        let context = CGContext(
            data: nil, width: 600, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: orange.red, green: orange.green, blue: orange.blue, alpha: 1))
        context.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        context.setFillColor(CGColor(srgbRed: purple.red, green: purple.green, blue: purple.blue, alpha: 1))
        context.fill(CGRect(x: 400, y: 400, width: 6, height: 6))

        #expect(LegendMatcher.bestMatchIndex(for: context.makeImage()!, among: [first, second]) == 1)
    }

    @Test("Grey legend colours do not count, and a page with none of the colours matches nothing")
    func ignoresGreyAndMisses() {
        let greyLegend = Legend(entries: [LegendEntry(name: "Wall", color: grey)])
        let orangeLegend = Legend(entries: [LegendEntry(name: "Booth A", color: orange)])

        #expect(LegendMatcher.bestMatchIndex(for: page(painting: grey), among: [greyLegend, orangeLegend]) == nil)
    }

    @Test("A single legend is always the one used")
    func singleLegend() {
        let only = Legend(entries: [LegendEntry(name: "Booth A", color: purple)])

        #expect(LegendMatcher.bestMatchIndex(for: page(painting: orange), among: [only]) == 0)
    }
}

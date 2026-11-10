import Testing
@testable import BazaarSimulator

@Suite
struct PrintedScaleTests {
    @Test("A printed size is read with or without the first unit and with a comma decimal")
    func readsSizes() {
        #expect(PrintedScale.size(in: "STAGE 6 x 12 m") == PrintedSize(long: 12, short: 6))
        #expect(PrintedScale.size(in: "EXT 3m x 3m") == PrintedSize(long: 3, short: 3))
        #expect(PrintedScale.size(in: "2,5 X 4 m") == PrintedSize(long: 4, short: 2.5))
        #expect(PrintedScale.size(in: "Hall 12 metres") == nil)
    }

    @Test("The scale is the median over boxes whose two sides agree, whichever way the box is turned")
    func medianScale() {
        let scale = PrintedScale.pixelsPerMetre(from: [
            (box: [0, 0, 394, 197], printed: PrintedSize(long: 12, short: 6)),
            (box: [0, 0, 98, 99], printed: PrintedSize(long: 3, short: 3)),
            (box: [0, 0, 197, 394], printed: PrintedSize(long: 12, short: 6))
        ])

        #expect(scale.map { abs($0 - 32.8) < 0.5 } == true)
    }

    @Test("A box whose sides give different scales is not used")
    func rejectsMismatchedBox() {
        let printed = PrintedSize(long: 12, short: 6)

        let scale = PrintedScale.pixelsPerMetre(from: [(box: [0, 0, 300, 100], printed: printed)])

        #expect(scale == nil)
    }
}

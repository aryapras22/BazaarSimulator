import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads the text printed inside boxes of a plan. The extractor tells classes apart by colour, so classes with
/// the same swatch come back as one. It also reads no scale and no booth number without a letter in front.
/// The words printed in the boxes settle all three.
enum PlanPrintedText {
    private static let structuralClasses: Set<String> = [
        "wall", "door", "opening", "gate", "object", "pillar", "blocked", "entrance", "exit"
    ]
    private static let orientations: [CGImagePropertyOrientation] = [.up, .down, .left, .right]
    private static let maxSizedBoxes = 8
    private static let sampledBooths = 16
    /// How far around a booth its side label is looked for, in booth sides.
    private static let sideLabelReach = 0.6
    private static let paperWhite = 250
    private static let gateWord = "gate"

    /// A legend class drawn as an outline has a paper white swatch, so the extractor gives it every empty outlined
    /// region of the plan: rooms, stairs, voids. A box of such a class is kept only when it prints the name of a
    /// legend class, and takes that name. Booths are left alone, because an ID already tells them apart.
    static func keepingNamedPaperWhiteBoxes(
        _ items: [DetectedItem],
        classNames: [String],
        on page: CGImage
    ) async -> [DetectedItem] {
        var result: [DetectedItem] = []
        for var item in items {
            guard isPaperWhite(item), !item.isBooth else {
                result.append(item)
                continue
            }
            let words = await words(in: item.box, on: page) { className(printedIn: $0, among: classNames) != nil }
            guard let name = className(printedIn: words, among: classNames) else { continue }
            item.cls = name
            result.append(item)
        }
        return result
    }

    /// The extractor reads booth IDs that start with letters. Plans that print bare numbers come back without IDs,
    /// so the number printed in each such booth is read here.
    static func numberingBooths(_ items: [DetectedItem], on page: CGImage) async -> [DetectedItem] {
        var result = items
        for index in items.indices where items[index].id == nil && items[index].cls.lowercased().contains("booth") {
            let words = await words(in: items[index].box, on: page) { boothNumber(in: $0) != nil }
            result[index].id = boothNumber(in: words)
        }
        return result
    }

    /// A legend class called gate is drawn as a bar that the extractor returns nothing for. The word GATE printed
    /// beside the bar marks where it is, so a gate is placed on each such word, as long as the word is.
    static func addingPrintedGates(
        _ items: [DetectedItem],
        classNames: [String],
        on page: CGImage
    ) async -> [DetectedItem] {
        guard classNames.contains(where: { letters(of: $0).contains(gateWord) }) else { return items }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard let observations = try? await request.perform(on: page) else { return items }
        let width = Double(page.width)
        let height = Double(page.height)
        let gates = observations.filter { letters(of: $0.transcript) == gateWord }.map { observation in
            // Vision measures from the bottom left in fractions of the page.
            let box = observation.boundingBox.cgRect
            return DetectedItem(
                cls: "gate",
                box: [box.minX * width, (1 - box.maxY) * height, box.width * width, box.height * height]
            )
        }
        return items + gates
    }

    /// The longest class name the words spell out, ignoring case, spaces and line breaks.
    static func className(printedIn words: [String], among classNames: [String]) -> String? {
        let printed = letters(of: words.joined())
        return classNames
            .filter { !letters(of: $0).isEmpty && printed.contains(letters(of: $0)) }
            .max { letters(of: $0).count < letters(of: $1).count }
    }

    /// The first word that is a number of up to three digits, with up to two letters in front.
    static func boothNumber(in words: [String]) -> String? {
        words
            .flatMap { $0.split(separator: " ") }
            .map { String($0).uppercased() }
            .first { $0.wholeMatch(of: #/[A-Z]{0,2}[0-9]{1,3}/#) != nil }
    }

    private static func letters(of text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func isPaperWhite(_ item: DetectedItem) -> Bool {
        item.legendRgb.count == 3 && item.legendRgb.allSatisfy { $0 >= paperWhite }
    }

    /// Pixels per metre from boxes that print their size, such as "6 x 12 m" on a stage, else from classes whose
    /// legend name prints one, else from the side printed beside the booths.
    static func pixelsPerMetre(from items: [DetectedItem], on page: CGImage) async -> Double? {
        let unsized = items.filter { item in
            !item.isBooth && !structuralClasses.contains(item.cls.lowercased())
        }
        let candidates = unsized.sorted { area(of: $0) > area(of: $1) }.prefix(maxSizedBoxes)
        var printedBoxes: [(box: [Double], printed: PrintedSize)] = []
        for item in candidates {
            func size(in words: [String]) -> PrintedSize? { PrintedScale.size(in: words.joined(separator: " ")) }
            let words = await words(in: item.box, on: page) { size(in: $0) != nil }
            if let printed = size(in: words) { printedBoxes.append((item.box, printed)) }
        }
        if let scale = PrintedScale.pixelsPerMetre(from: printedBoxes)
            ?? PrintedScale.pixelsPerMetre(from: boxesSizedByClassName(items)) {
            return scale
        }
        return await pixelsPerMetreFromBoothSides(items, on: page)
    }

    /// Some plans print no box size but print a side such as "3 m" beside each booth. The side printed most often
    /// around a sample of booths is taken as the side of the median booth. The labels are too small to read on the
    /// whole page, so each sampled booth is read on its own.
    private static func pixelsPerMetreFromBoothSides(_ items: [DetectedItem], on page: CGImage) async -> Double? {
        let booths = items.filter(\.isBooth)
        let sides = booths.map { ($0.box[2] + $0.box[3]) / 2 }.sorted()
        guard !sides.isEmpty else { return nil }
        let medianSide = sides[sides.count / 2]
        let reach = medianSide * sideLabelReach
        var printed: [Double] = []
        for index in stride(from: 0, to: booths.count, by: max(1, booths.count / sampledBooths)) {
            let box = booths[index].box
            let around = [box[0] - reach, box[1] - reach, box[2] + 2 * reach, box[3] + 2 * reach]
            printed += await words(in: around, on: page) { _ in true }.compactMap(PrintedScale.length(in:))
        }
        return PrintedScale.mostPrinted(printed).map { medianSide / $0 }
    }

    /// A legend class such as "Booth, goods (3 x 2 m)" prints the size of every box of the class.
    private static func boxesSizedByClassName(_ items: [DetectedItem]) -> [(box: [Double], printed: PrintedSize)] {
        items.compactMap { item in PrintedScale.size(in: item.cls).map { (item.box, $0) } }
    }

    private static func area(of item: DetectedItem) -> Double {
        item.box[2] * item.box[3]
    }

    /// Tries the page upright, then turned, and stops at the first turn whose words are `enough`.
    private static func words(
        in box: [Double],
        on page: CGImage,
        until enough: ([String]) -> Bool
    ) async -> [String] {
        let bounds = CGRect(x: 0, y: 0, width: page.width, height: page.height)
        let padded = CGRect(x: box[0], y: box[1], width: box[2], height: box[3]).insetBy(dx: -3, dy: -3)
        let rect = padded.intersection(bounds)
        guard !rect.isEmpty, let crop = page.cropping(to: rect.integral) else { return [] }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        var found: [String] = []
        for orientation in orientations {
            guard let observations = try? await request.perform(on: crop, orientation: orientation) else { continue }
            found += observations.map(\.transcript)
            if enough(found) { break }
        }
        return found
    }
}

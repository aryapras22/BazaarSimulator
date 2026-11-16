import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads the text printed inside boxes of a plan. The extractor tells classes apart by colour, so classes with
/// the same swatch come back as one. It also reads no scale and no booth number without a letter in front.
/// The words printed in the boxes settle all three.
enum PlanPrintedText {
    private static let structuralClasses: Set<String> = [
        "wall", "door", "opening", "object", "pillar", "blocked", "entrance", "exit"
    ]
    private static let orientations: [CGImagePropertyOrientation] = [.up, .down, .left, .right]
    private static let maxSizedBoxes = 8
    private static let paperWhite = 250

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
    /// legend name prints one.
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
        return PrintedScale.pixelsPerMetre(from: printedBoxes)
            ?? PrintedScale.pixelsPerMetre(from: boxesSizedByClassName(items))
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

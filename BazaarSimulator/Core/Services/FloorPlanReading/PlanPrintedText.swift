import CoreGraphics
import Foundation
import ImageIO
import Vision

/// Reads the text printed inside boxes of a plan. The extractor tells classes apart by colour, so two classes with
/// nearly the same swatch (Decor and Entrance) come back as one, and it reads no scale. The words printed in the
/// boxes settle both.
enum PlanPrintedText {
    private static let structuralClasses: Set<String> = [
        "wall", "door", "opening", "object", "pillar", "blocked", "entrance", "exit"
    ]
    private static let orientations: [CGImagePropertyOrientation] = [.up, .down, .left, .right]
    private static let maxSizedBoxes = 8

    /// Entrance boxes that print "DECOR" are decor blocks. Other entrance boxes, such as window frames, stay as is.
    static func relabelingDecor(_ items: [DetectedItem], on page: CGImage) async -> [DetectedItem] {
        var result = items
        for index in items.indices where items[index].cls.lowercased() == "entrance" {
            let words = await words(in: items[index].box, on: page)
            if words.contains(where: { $0.localizedCaseInsensitiveContains("decor") }) {
                result[index].cls = "Decor"
            }
        }
        return result
    }

    /// Pixels per metre from boxes that print their size, such as "6 x 12 m" on a stage.
    static func pixelsPerMetre(from items: [DetectedItem], on page: CGImage) async -> Double? {
        let unsized = items.filter { item in
            let name = item.cls.lowercased()
            return !name.contains("booth") && !structuralClasses.contains(name)
        }
        let candidates = unsized.sorted { area(of: $0) > area(of: $1) }.prefix(maxSizedBoxes)
        var printedBoxes: [(box: [Double], printed: PrintedSize)] = []
        for item in candidates {
            let text = await words(in: item.box, on: page).joined(separator: " ")
            if let printed = PrintedScale.size(in: text) { printedBoxes.append((item.box, printed)) }
        }
        return PrintedScale.pixelsPerMetre(from: printedBoxes)
    }

    private static func area(of item: DetectedItem) -> Double {
        item.box[2] * item.box[3]
    }

    private static func words(in box: [Double], on page: CGImage) async -> [String] {
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
            if PrintedScale.size(in: found.joined(separator: " ")) != nil { break }
        }
        return found
    }
}

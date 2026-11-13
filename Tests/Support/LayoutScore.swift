import Foundation
import simd
@testable import BazaarSimulator

/// How close a layout read from a plan is to the truth layout of the same plan. Both are in the truth's metres.
struct LayoutScore: Equatable, Sendable {
    /// Imported size over true size, so 1.2 is a layout a fifth too large.
    var sizeRatio: Double
    var truthBooths: Int
    var boothsFound: Int
    var boothLabelsRight: Int
    var extraBooths: Int
    var truthDoors: Int
    var doorsFound: Int
    var extraDoors: Int
    /// Hall area the two layouts share, over the area either of them covers.
    var hallOverlap: Double
}

extension LayoutScore {
    private static let minBoothOverlap = 0.5
    private static let doorSlackM = 0.5
    private static let hallCellM = 0.5

    init(of layout: Layout, against truth: Layout, sizeRatio: Double) {
        let booths = layout.objects.filter { $0.kind == .booth }
        let truthBooths = truth.objects.filter { $0.kind == .booth }
        let boothBounds = booths.map { LayoutGeometry.bounds(of: $0.placement) }
        let truthBoothBounds = truthBooths.map { LayoutGeometry.bounds(of: $0.placement) }
        let boothPairs = Self.pairs(truthBooths.count, booths.count) { truthIndex, index in
            let overlap = Self.overlap(truthBoothBounds[truthIndex], boothBounds[index])
            return overlap >= Self.minBoothOverlap ? overlap : nil
        }

        let doors = layout.objects.filter { $0.kind == .door }
        let truthDoors = truth.objects.filter { $0.kind == .door }
        let doorPairs = Self.pairs(truthDoors.count, doors.count) { truthIndex, index in
            let truthDoor = truthDoors[truthIndex].placement
            let reach = max(truthDoor.sizeM.x, truthDoor.sizeM.y) / 2 + Self.doorSlackM
            let distance = simd_distance(truthDoor.center, doors[index].placement.center)
            return distance <= reach ? -distance : nil
        }

        self.init(
            sizeRatio: Self.rounded(sizeRatio),
            truthBooths: truthBooths.count,
            boothsFound: boothPairs.count,
            boothLabelsRight: boothPairs.filter { truthBooths[$0.truth].label == booths[$0.found].label }.count,
            extraBooths: booths.count - boothPairs.count,
            truthDoors: truthDoors.count,
            doorsFound: doorPairs.count,
            extraDoors: doors.count - doorPairs.count,
            hallOverlap: Self.rounded(Self.hallOverlap(layout.hall, truth.hall))
        )
    }

    /// Each truth item paired with at most one found item, closest pairs first. `closeness` is nil for no match.
    private static func pairs(
        _ truthCount: Int,
        _ foundCount: Int,
        closeness: (Int, Int) -> Double?
    ) -> [(truth: Int, found: Int)] {
        var candidates: [(closeness: Double, pair: (truth: Int, found: Int))] = []
        for truth in 0..<truthCount {
            for found in 0..<foundCount {
                if let value = closeness(truth, found) { candidates.append((value, (truth, found))) }
            }
        }
        var usedTruth = Set<Int>()
        var usedFound = Set<Int>()
        var result: [(truth: Int, found: Int)] = []
        for (_, pair) in candidates.sorted(by: { $0.closeness > $1.closeness })
        where !usedTruth.contains(pair.truth) && !usedFound.contains(pair.found) {
            usedTruth.insert(pair.truth)
            usedFound.insert(pair.found)
            result.append(pair)
        }
        return result
    }

    /// Shared area of two boxes over the area either covers.
    private static func overlap(_ first: BoundingBox, _ second: BoundingBox) -> Double {
        let width = min(first.maxX, second.maxX) - max(first.minX, second.minX)
        let height = min(first.maxY, second.maxY) - max(first.minY, second.minY)
        guard width > 0, height > 0 else { return 0 }
        let shared = width * height
        return shared / (area(of: first) + area(of: second) - shared)
    }

    private static func area(of box: BoundingBox) -> Double {
        (box.maxX - box.minX) * (box.maxY - box.minY)
    }

    /// Counted on a grid of points, which is exact enough for halls tens of metres wide.
    private static func hallOverlap(_ first: [SIMD2<Double>], _ second: [SIMD2<Double>]) -> Double {
        let box = LayoutGeometry.bounds(of: first + second)
        var shared = 0
        var either = 0
        for pointX in stride(from: box.minX + hallCellM / 2, to: box.maxX, by: hallCellM) {
            for pointY in stride(from: box.minY + hallCellM / 2, to: box.maxY, by: hallCellM) {
                let point = SIMD2(pointX, pointY)
                let inFirst = LayoutGeometry.polygonContains(first, point: point)
                let inSecond = LayoutGeometry.polygonContains(second, point: point)
                shared += inFirst && inSecond ? 1 : 0
                either += inFirst || inSecond ? 1 : 0
            }
        }
        return either == 0 ? 0 : Double(shared) / Double(either)
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

/// Where a truth file's metres sit on its plan image: pixel = (metres - 1) * pixelsPerMetre + origin.
struct MockPlanFrame: Decodable {
    struct ImageSize: Decodable {
        let width: Double
        let height: Double
    }

    let pixelsPerMetre: Double
    let origin: [Double]
    let image: ImageSize

    enum CodingKeys: String, CodingKey {
        case pixelsPerMetre = "px_per_m"
        case origin = "origin_px"
        case image
    }

    /// The reader sees the plan drawn with its long side at the import size, not at the size of the image file.
    private var renderScale: Double {
        Double(PDFImportService.longSidePixels) / max(image.width, image.height)
    }

    /// The true scale of the page the reader saw.
    var renderedPixelsPerMetre: Double {
        pixelsPerMetre * renderScale
    }

    /// The layout moved from its own metres into the truth's, through the pixels of the page it was read from.
    /// The mapper puts the top left of everything it found one margin in from the corner, so that rule is undone here.
    func inTruthMetres(_ layout: Layout, readFrom plan: DetectedPlan, pixelsPerMetre: Double) -> Layout {
        let layoutOrigin = SIMD2(plan.items.map { $0.box[0] }.min() ?? 0, plan.items.map { $0.box[1] }.min() ?? 0)
        let truthOrigin = SIMD2(origin[0], origin[1]) * renderScale
        let truthScale = renderedPixelsPerMetre
        func truthMetres(_ point: SIMD2<Double>) -> SIMD2<Double> {
            let pixel = (point - ExtractedLayoutMapper.marginM) * pixelsPerMetre + layoutOrigin
            return (pixel - truthOrigin) / truthScale + 1
        }

        var result = layout
        result.hall = layout.hall.map(truthMetres)
        for index in result.objects.indices {
            result.objects[index].placement.center = truthMetres(layout.objects[index].placement.center)
            result.objects[index].placement.sizeM *= pixelsPerMetre / truthScale
        }
        return result
    }
}

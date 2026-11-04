import Foundation
import simd

enum ExtractedLayoutMapper {
    private static let hallClasses: Set<String> = ["blocked", "entrance", "exit"]

    static let marginM = 1.0
    static let minWallThicknessM = 0.2
    /// The extractor reads no scale. Booths measure 2 to 3 m on the sample plans, so the median booth is taken as 2.5 m
    /// until the user calibrates.
    static let assumedBoothSideM = 2.5

    /// Legend classes that describe the hall, not a booth category. They stay out of the project legend.
    static func isHallClass(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return hallClasses.contains(lowered) || lowered.contains("stage")
    }

    static func assumedPixelsPerMetre(for plan: DetectedPlan) -> Double? {
        let sides = plan.items
            .filter(isBooth)
            .map { ($0.box[2] + $0.box[3]) / 2 }
            .sorted()
        guard !sides.isEmpty else { return nil }
        return sides[sides.count / 2] / assumedBoothSideM
    }

    static func layout(
        from plan: DetectedPlan,
        legend: Legend,
        pixelsPerMetre: Double,
        id: UUID = UUID(),
        name: String
    ) -> Layout {
        let origin = SIMD2<Double>(
            plan.items.map { $0.box[0] }.min() ?? 0,
            plan.items.map { $0.box[1] }.min() ?? 0
        )
        func metres(_ pxX: Double, _ pxY: Double) -> SIMD2<Double> {
            SIMD2<Double>((pxX - origin.x) / pixelsPerMetre + marginM, (pxY - origin.y) / pixelsPerMetre + marginM)
        }

        var unlabeled = 0
        var objects: [LayoutObject] = []
        for item in plan.items {
            let frame = rect(of: item, metres: metres, pixelsPerMetre: pixelsPerMetre)
            if let object = object(for: item, legend: legend, placement: frame, unlabeled: &unlabeled) {
                objects.append(object)
            }
        }

        let hall = hallPolygon(from: objects)
        let extent = hall.reduce(SIMD2<Double>.zero) { SIMD2(max($0.x, $1.x), max($0.y, $1.y)) }
        var layout = Layout(
            id: id,
            name: name,
            sizeM: extent + SIMD2<Double>(repeating: marginM),
            hall: hall,
            objects: objects,
            source: LayoutSource(
                name: name,
                note: "Read from the PDF. Scale assumed from booth size "
                    + "(\(DimensionInput.text(for: pixelsPerMetre)) px/m)."
            )
        )
        for index in layout.objects.indices where layout.objects[index].kind == .booth {
            layout.objects[index].openSides = OpenSideInference.infer(for: layout.objects[index], in: layout)
        }
        return layout
    }

    private static func isBooth(_ item: DetectedItem) -> Bool {
        item.cls.lowercased().contains("booth")
    }

    /// The legend entry with the item's colour, else the one with its name.
    private static func category(for item: DetectedItem, in legend: Legend) -> LegendEntry? {
        guard item.legendRgb.count == 3 else {
            return legend.entries.first { $0.name.caseInsensitiveCompare(item.cls) == .orderedSame }
        }
        let target = item.legendRgb.map { Double($0) / 255 }
        return legend.entries.min { distance($0.color, target) < distance($1.color, target) }
    }

    private static func distance(_ color: LegendColor, _ target: [Double]) -> Double {
        let diff = SIMD3(color.red - target[0], color.green - target[1], color.blue - target[2])
        return simd_length_squared(diff)
    }

    private static func rect(
        of item: DetectedItem,
        metres: (Double, Double) -> SIMD2<Double>,
        pixelsPerMetre: Double
    ) -> Placement {
        if item.cls == "wall", let segment = item.segment, segment.count == 4 {
            let start = metres(segment[0], segment[1])
            let end = metres(segment[2], segment[3])
            let thickness = max((item.widthPx ?? 0) / pixelsPerMetre, minWallThicknessM)
            return Placement(
                center: (start + end) / 2,
                sizeM: SIMD2<Double>(simd_length(end - start), thickness),
                rotationRadians: atan2(end.y - start.y, end.x - start.x)
            )
        }
        let topLeft = metres(item.box[0], item.box[1])
        let size = SIMD2<Double>(item.box[2], item.box[3]) / pixelsPerMetre
        return Placement(center: topLeft + size / 2, sizeM: size)
    }

    private static func object(
        for item: DetectedItem,
        legend: Legend,
        placement: Placement,
        unlabeled: inout Int
    ) -> LayoutObject? {
        let lowered = item.cls.lowercased()
        switch lowered {
        case "wall":
            return LayoutObject(kind: .wall, label: "Wall", placement: placement, reviewState: .detected)
        case "pillar":
            return LayoutObject(kind: .pillar, label: "Pillar", placement: placement, reviewState: .detected)
        case "opening":
            return LayoutObject(
                kind: .door,
                label: "Door",
                placement: placement,
                doorFlow: DoorFlow(direction: .both),
                reviewState: .detected
            )
        case "blocked":
            return LayoutObject(kind: .closedArea, label: "Blocked", placement: placement, reviewState: .detected)
        case "entrance", "exit":
            return LayoutObject(kind: .fixture, label: item.cls, placement: placement, reviewState: .detected)
        case "door":
            return nil
        case "object":
            guard item.kind == "table" else { return nil }
            return LayoutObject(kind: .table, label: "Table", placement: placement, reviewState: .detected)
        default:
            return legendObject(for: item, legend: legend, placement: placement, unlabeled: &unlabeled)
        }
    }

    private static func legendObject(
        for item: DetectedItem,
        legend: Legend,
        placement: Placement,
        unlabeled: inout Int
    ) -> LayoutObject {
        if isHallClass(item.cls) {
            return LayoutObject(kind: .stage, label: "Stage", placement: placement, reviewState: .detected)
        }
        guard isBooth(item) else {
            return LayoutObject(kind: .fixture, label: item.cls, placement: placement, reviewState: .detected)
        }
        unlabeled += item.id == nil ? 1 : 0
        return LayoutObject(
            kind: .booth,
            label: item.id ?? "U\(unlabeled)",
            placement: placement,
            categoryID: category(for: item, in: legend)?.id,
            reviewState: .detected
        )
    }

    /// The bounding box of the walls and pillars, or of everything when no wall was found.
    private static func hallPolygon(from objects: [LayoutObject]) -> [SIMD2<Double>] {
        let structure = objects.filter { $0.kind == .wall || $0.kind == .pillar }
        let basis = structure.isEmpty ? objects : structure
        guard !basis.isEmpty else { return [] }
        let corners = basis.flatMap { LayoutGeometry.corners(of: $0.placement) }
        let low = corners.reduce(corners[0]) { SIMD2(min($0.x, $1.x), min($0.y, $1.y)) }
        let high = corners.reduce(corners[0]) { SIMD2(max($0.x, $1.x), max($0.y, $1.y)) }
        return [low, SIMD2(high.x, low.y), high, SIMD2(low.x, high.y)]
    }
}

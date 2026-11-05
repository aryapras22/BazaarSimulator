import CoreGraphics
import Extractor
import Foundation

enum FloorPlanReadingError: Error {
    case noBooths
}

struct ExtractorFloorPlanReader: FloorPlanReading {
    func readLegend(_ page: CGImage) async throws -> Legend {
        let swatches = try await PlanExtractor.legend(in: page)
        let entries = swatches
            .filter { !ExtractedLayoutMapper.isHallClass($0.label) }
            .map { swatch in
                LegendEntry(
                    name: swatch.label,
                    color: LegendColor(
                        red: Double(swatch.rgb[0]) / 255,
                        green: Double(swatch.rgb[1]) / 255,
                        blue: Double(swatch.rgb[2]) / 255
                    )
                )
            }
        return Legend(entries: entries)
    }

    func readPlan(
        _ page: CGImage,
        legendPage: CGImage,
        legend: Legend,
        name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExtractedLayout {
        let reading = try await PlanExtractor.plan(page, legend: legendPage, onProgress: onProgress)
        let detected = DetectedPlan(items: reading.items.map(Self.detectedItem))
        guard let scale = ExtractedLayoutMapper.assumedPixelsPerMetre(for: detected) else {
            throw FloorPlanReadingError.noBooths
        }
        return ExtractedLayout(
            layout: ExtractedLayoutMapper.layout(from: detected, legend: legend, pixelsPerMetre: scale, name: name)
        )
    }

    private static func detectedItem(_ item: PlanItem) -> DetectedItem {
        DetectedItem(
            cls: item.cls,
            box: item.box.map(Double.init),
            id: item.id,
            segment: item.segment?.map(Double.init),
            widthPx: item.width,
            kind: item.kind,
            legendRgb: item.legendRgb,
            chairs: item.chairs
        )
    }
}

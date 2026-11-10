import CoreGraphics
import Extractor
import Foundation
import os

enum FloorPlanReadingError: Error {
    case noBooths
}

struct ExtractorFloorPlanReader: FloorPlanReading {
    /// The legend table's own header words, which the extractor can read as classes.
    private static let legendHeaderWords: Set<String> = ["class", "symbol"]

    private let symbolStore: SymbolLegendStore

    init(symbolStore: SymbolLegendStore = .shared) {
        self.symbolStore = symbolStore
    }

    func readLegend(_ page: CGImage) async throws -> Legend {
        let swatches = try await PlanExtractor.legend(in: page)
        let entries = swatches
            .filter { swatch in
                !ExtractedLayoutMapper.isHallClass(swatch.label)
                    && !Self.legendHeaderWords.contains(swatch.label.lowercased())
            }
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
        let detected = try await detectPlan(page, legendPage: legendPage, onProgress: onProgress)
        let printedScale = detected.printedPixelsPerMetre
        guard let scale = printedScale ?? ExtractedLayoutMapper.assumedPixelsPerMetre(for: detected) else {
            throw FloorPlanReadingError.noBooths
        }
        let layout = ExtractedLayoutMapper.layout(
            from: detected,
            legend: legend,
            pixelsPerMetre: scale,
            name: name,
            scaleBasis: printedScale == nil ? "booth size" : "printed sizes"
        )
        Self.logLedger(of: detected, layout: layout)
        return ExtractedLayout(layout: layout)
    }

    /// Everything read from the page before it is mapped to metres.
    func detectPlan(
        _ page: CGImage,
        legendPage: CGImage,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> DetectedPlan {
        let reading = try await PlanExtractor.plan(
            page,
            legend: legendPage,
            symbols: symbolStore.symbols,
            onProgress: onProgress
        )
        let items = await PlanPrintedText.relabelingDecor(reading.items.map(Self.detectedItem), on: page)
        return DetectedPlan(
            items: items,
            printedPixelsPerMetre: await PlanPrintedText.pixelsPerMetre(from: items, on: page)
        )
    }

    /// Items that came in against what reached the layout, so a class the mapper discards shows up in the log.
    private static func logLedger(of plan: DetectedPlan, layout: Layout) {
        let raw = Dictionary(grouping: plan.items) { $0.kind ?? $0.cls }.mapValues(\.count)
        let summary = raw.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        Logger.reading.info("read \(plan.items.count) items (\(summary)), kept \(layout.objects.count) objects")
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
            chairs: item.chairs,
            symbolClass: item.symbolClass
        )
    }
}

private extension Logger {
    static let reading = Logger(subsystem: "BazaarSimulator", category: "ExtractorFloorPlanReader")
}

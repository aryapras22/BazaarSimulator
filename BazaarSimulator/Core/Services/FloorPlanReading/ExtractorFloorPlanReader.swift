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
        onEvent: @escaping @MainActor @Sendable (PlanReadingEvent) -> Void
    ) async throws -> ExtractedLayout {
        let detected = try await detectPlan(page, legendPage: legendPage) { progress in
            Task { @MainActor in onEvent(.progress(progress)) }
        }
        let itemSummary = Self.itemSummary(of: detected)
        onEvent(.note("Plan read: \(detected.items.count) items (\(itemSummary))"))
        let printedScale = detected.printedPixelsPerMetre
        guard let scale = printedScale ?? ExtractedLayoutMapper.assumedPixelsPerMetre(for: detected) else {
            throw FloorPlanReadingError.noBooths
        }
        let scaleBasis = printedScale == nil ? "booth size" : "printed sizes"
        let scaleText = scale.formatted(.number.precision(.fractionLength(1)))
        onEvent(.note("Scale: \(scaleText) px per metre from \(scaleBasis)"))
        let layout = ExtractedLayoutMapper.layout(
            from: detected,
            legend: legend,
            pixelsPerMetre: scale,
            name: name,
            scaleBasis: scaleBasis
        )
        // Items that came in against what reached the layout, so a class the mapper discards shows up in the log.
        Logger.reading.info("read \(detected.items.count) items (\(itemSummary)), kept \(layout.objects.count) objects")
        onEvent(.note("Mapped to a layout: kept \(layout.objects.count) objects"))
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

    private static func itemSummary(of plan: DetectedPlan) -> String {
        let raw = Dictionary(grouping: plan.items) { $0.kind ?? $0.cls }.mapValues(\.count)
        return raw.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
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

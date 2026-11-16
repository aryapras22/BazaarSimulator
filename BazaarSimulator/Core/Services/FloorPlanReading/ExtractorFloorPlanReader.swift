import CoreGraphics
import Extractor
import Foundation
import os

enum FloorPlanReadingError: Error {
    case noBooths
    case noLegend
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
        onEvent(.progress(0.08, step: "Scanning plan..."))
        let detected = try await detectPlan(page, legendPage: legendPage) { progress, step in
            onEvent(.progress(progress, step: step))
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
        onEvent(.progress(0.96, step: "Building layout..."))
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
        onStage: @escaping @MainActor @Sendable (Double, String) -> Void = { _, _ in }
    ) async throws -> DetectedPlan {
        let reading = try await PlanExtractor.plan(
            page,
            legend: legendPage,
            symbols: symbolStore.symbols
        ) { progress in
            let stage = Self.extractorStage(for: progress)
            Task { @MainActor in onStage(stage.progress, stage.step) }
        }
        onStage(0.65, "Reading zone labels...")
        let named = await PlanPrintedText.keepingNamedPaperWhiteBoxes(
            reading.items.map(Self.detectedItem),
            classNames: reading.legend.map(\.label),
            on: page
        )
        onStage(0.75, "Reading booth numbers...")
        let numbered = await PlanPrintedText.numberingBooths(named, on: page)
        let items = await PlanPrintedText.addingPrintedGates(
            numbered,
            classNames: reading.legend.map(\.label),
            on: page
        )
        onStage(0.90, "Reading scale...")
        return DetectedPlan(
            items: items,
            printedPixelsPerMetre: await PlanPrintedText.pixelsPerMetre(from: items, on: page)
        )
    }

    private nonisolated static func extractorStage(for progress: Double) -> (progress: Double, step: String) {
        if progress < 0.15 { return (0.15, "Detecting booths...") }
        if progress < 0.50 { return (0.35, "Detecting walls & doors...") }
        if progress < 0.80 { return (0.50, "Reading booth IDs...") }
        if progress < 0.95 { return (0.60, "Reviewing detections...") }
        return (0.64, "Reviewing detections...")
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

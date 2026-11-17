import CoreGraphics
import Foundation

enum PlanReadingEvent: Sendable {
    case progress(Double, step: String? = nil)
    case note(String)
}

protocol FloorPlanReading: Sendable {
    func readLegend(_ page: CGImage) async throws -> Legend
    func readPlan(
        _ page: CGImage,
        legendPage: CGImage,
        legend: Legend,
        name: String,
        onEvent: @escaping @MainActor @Sendable (PlanReadingEvent) -> Void
    ) async throws -> ExtractedLayout
}

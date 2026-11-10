import CoreGraphics
import Foundation

protocol FloorPlanReading: Sendable {
    func readLegend(_ page: CGImage) async throws -> Legend
    func readPlan(
        _ page: CGImage,
        legendPage: CGImage,
        legend: Legend,
        name: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> ExtractedLayout
}
